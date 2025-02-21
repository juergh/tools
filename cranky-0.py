#!/usr/bin/env python3

import os
import sys
from subprocess import CalledProcessError, check_call

import click
from debian.changelog import Changelog

CRANKY = os.getenv("CRANKY", "cranky")
COLS = int(os.popen("tput cols", "r").read().strip())


def source_debian_env():
    with open("debian/debian.env", encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("DEBIAN="):
                return line.strip().split("=")[1]
    return None


def parse_changelog(changelog=None, offset=0):
    if not changelog:
        changelog = f"{source_debian_env()}/changelog"

    with open(changelog, encoding="utf-8") as fh:
        return Changelog(fh)[offset]


def print_banner(cmd, invert=True, color=9):
    txt = " ".join(cmd) + " " * COLS
    x = 48 if invert else 38
    print(f"\033[{x};5;{color}m{txt[:COLS]}\033[0m")


def run(cmd, shell=False):
    print()
    print_banner(cmd)
    try:
        if cmd[0] == "cranky":
            print_banner([os.popen("which cranky", "r").read().strip()], invert=False)

        if shell:
            check_call(" ".join(cmd), bufsize=0, shell=True)
        else:
            check_call(cmd, bufsize=0)
    except CalledProcessError as e:
        print("Error: " + str(e))
        sys.exit(1)


@click.group()
def main():
    pass


@main.command()
def fix():
    series = parse_changelog().distributions
    if series != "UNRELEASED":
        print(f"Invalid series: {series}", file=sys.stderr)
        sys.exit(1)

    run([CRANKY, "fix"])


@main.command()
@click.option("--dry-run", is_flag=True)
def rebase(dry_run):
    opts = []
    if dry_run:
        opts += ["--dry-run"]

    ch = parse_changelog()
    if ch.package == "linux-raspi-realtime":
        run(["cranky-update-to"] + opts + ["--strategy", "rebase", "raspi"])
        run(["cranky-update-to"] + opts + ["--strategy", "cherry-pick", "realtime"])
        return

    print("Error: Not implemented yet")
    sys.exit(1)


@main.command(name="open")
def open_():
    series = parse_changelog().distributions
    if series == "UNRELEASED":
        print(f"Invalid series: {series}", file=sys.stderr)
        sys.exit(1)

    run(["git", "clean", "-dxf"])
    run([CRANKY, "open"])


@main.command()
def configs():
    run([CRANKY, "updateconfigs"])


@main.command()
@click.option("--dry-run", is_flag=True)
@click.option("--re-run", is_flag=True)
@click.option("--cycle", required=True, help="SRU cycle name.")
def link(dry_run, re_run, cycle):
    opts = []
    if dry_run:
        opts += ["--dry-run"]
    if re_run:
        opts += ["--re-run"]

    run([CRANKY, "link-tb", "--sru-cycle", cycle] + opts)


@main.command()
def dkms():
    if os.path.exists("update-dkms-versions"):
        print("Error: ./update-dkms-versions exists. This is unexpected!")
        sys.exit(1)

    run([CRANKY, "update-dkms-versions"])


@main.command(name="close")
@click.option("--force", is_flag=True)
def close_(force):
    series = parse_changelog().distributions
    if series != "UNRELEASED":
        print(f"Invalid series: {series}", file=sys.stderr)
        sys.exit(1)

    opts = []
    if force:
        opts += ["--force"]

    run([CRANKY, "close", "--use-cuc"])

    if parse_changelog().package == "linux-raspi-realtime":
        print()
        print("*** FIXME ***")
        print()

        # Reset HEAD
        run(["git", "reset", "--hard", "HEAD~1"])

        cl = "debian.raspi-realtime/changelog"

        #
        # raspi
        #
        version = str(parse_changelog("debian.raspi/changelog", offset=1).version)
        run([CRANKY, "update-changelog", "--changelog", cl,
             "--from-version", version,
             "--from-changelog", "debian.raspi/changelog"])

        #
        # realtime
        #
        version = str(parse_changelog("debian.realtime/changelog", offset=1).version)
        from_commit = os.popen("git log --format='%h __%s__' |" +
                               f"grep -m1 -F '__UBUNTU: Ubuntu-realtime-{version}__' | sed 's/ .*//'",
                               "r").read().strip()
        version = str(parse_changelog("debian.realtime/changelog").version)
        to_commit = os.popen("git log --format='%h __%s__' |" +
                             f"grep -m1 -F '__UBUNTU: Ubuntu-realtime-{version}__' | sed 's/ .*//'",
                             "r").read().strip()
        run([CRANKY, "update-changelog", "--changelog", cl,
             "--commit-range", f"{from_commit}..{to_commit}"])

        #
        # raspi-realtime
        #
        version = str(parse_changelog("debian.raspi-realtime/changelog", offset=1).version)
        from_commit = os.popen("git log --format='%h __%s__' |" +
                               f"grep -m1 -F '__UBUNTU: Ubuntu-raspi-realtime-{version}__' | sed 's/ .*//'",
                               "r").read().strip()
        run([CRANKY, "update-changelog", "--changelog", cl,
             "--from-commit", from_commit])

        # Commit
        series = parse_changelog(cl, offset=1).distributions
        version = str(parse_changelog(cl).version)
        run(["git", "add", cl])
        run(["dch", "--nomultimaint", "-c", cl, "-r", "-D", series, ""])
        run(["git", "commit", "-sam", f"UBUNTU: Ubuntu-raspi-realtime-{version}"])

    run([CRANKY, "tag"] + opts)


@main.command()
def dependents():
    run(["cranky-update-dependents", "-f"])


@main.command()
def verify():
    run(["cranky-verify-release-ready"])


@main.command()
@click.argument("pocket_offset_abi")
def build(pocket_offset_abi):
    run(["cranky-build-sources", "-f", pocket_offset_abi])


@main.command()
@click.argument("pocket_offset_abi")
def review(pocket_offset_abi):
    run(["cranky-review-sources", pocket_offset_abi])
    run(["cranky-reduce-debdiff"])

    run(["cranky-review-sources", "|", "less"], shell=True)
    run(["review-debdiff", "-r", "|", "less"], shell=True)


@main.command()
def push():
    run(["cranky-push-all", "--dry-run"])

    val = ""
    while val != "y":
        val = input("Push (y|n)? ")

    run(["cranky-push-all"])


@main.command()
@click.argument("ppa")
def dput(ppa):
    run([CRANKY, "dput-sources", ppa])


@main.command()
@click.option("--dry-run", is_flag=True)
def checkout(dry_run):
    opts = []
    if dry_run:
        opts += ["--dry-run"]
    run(["cranky-checkout"] + opts)


if __name__ == "__main__":
    main()
