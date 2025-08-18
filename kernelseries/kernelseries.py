# KernelSeries helper class

import gzip
import io
import json
import os
import time
from dataclasses import dataclass, field

import requests

from .logger import log

KS_CACHE = os.path.expanduser("~/.cache/kernel-series.json.gz")
KS_URL = "https://kernel.ubuntu.com/info/kernel-series.json.gz"


def load_from_file(fname):
    log.info(f"Load kernel-series data from {fname}")
    with gzip.open(fname) as fh:
        return json.load(fh)


def save_to_file(fname, ks):
    log.info(f"Save kernel-series data to {fname}")
    with gzip.open(fname, "w") as fh:
        fh.write(json.dumps(ks).encode("utf-8"))


def load_from_url(url):
    log.info(f"Load kernel-series data from {url}")
    r = requests.get(url, timeout=5)
    with gzip.open(io.BytesIO(r.content)) as fh:
        return json.load(fh)


@dataclass
class Base:
    def __str__(self):
        # return json.dumps(asdict(self), indent=2)
        return super().__str__()


@dataclass
class Repo(Base):
    package: Package  # The package this repo belongs to
    ks: list[str]  # The 'repo' list from kernelseries
    url: str = None
    branch: str = None

    def __post_init__(self):
        self.url = self.ks[0]
        self.branch = self.ks[1] if len(self.ks) > 1 else "master"


@dataclass
class Package(Base):
    source: Source  # The source this package belongs to
    name: str
    format: str  # snap or deb
    ks: dict  # The 'package' dict from kernelseries
    type: str = None
    repo: Repo = None

    def __post_init__(self):
        self.type = "snap" if self.format == "snap" else self.ks.get("type", "main")
        ks_repo = self.ks.get("repo")
        if ks_repo:
            self.repo = Repo(self, ks_repo)


@dataclass
class Source(Base):
    series: Series  # The series this source belongs to
    name: str
    ks: dict  # The 'source' dict from kernelseries
    ower: str = None
    devel: bool = None
    supported: bool = None
    active: bool = None
    copy_foward: bool = None
    backport: bool = None
    packages: list[Package] = None
    snaps: list[Package] = None

    def __post_init__(self):
        self.owner = self.ks.get("owner")
        self.devel = self.ks.get("development", self.series.devel)
        self.supported = self.ks.get("supported", True) if self.series.supported else False
        self.active = self.series.active and (self.devel or self.supported)
        self.copy_forward = self.ks.get("copy_forward", False)
        self.backport = self.ks.get("backport", False)

        self.packages = []
        for package, ks_package in self.ks.get("packages", {}).items():
            if ks_package:
                self.packages.append(Package(self, package, "deb", ks_package))

        self.snaps = []
        for snap, ks_snap in self.ks.get("snaps", {}).items():
            if ks_snap:
                self.packages.append(Package(self, snap, "snap", ks_snap))


@dataclass
class Series(Base):
    yymm: str
    ks: dict  # The 'series' dict from kernelseries
    name: str = None
    devel: bool = None
    supported: bool = None
    lts: bool = None
    esm: bool = None
    active: bool = None
    sources: list[Source] = None

    def __post_init__(self):
        self.name = self.ks["codename"]
        self.devel = self.ks.get("development", False)
        self.supported = self.ks.get("supported", False)
        self.lts = self.ks.get("lts", False)
        self.esm = self.ks.get("esm", False)
        self.active = self.devel or self.supported

        self.sources = []
        for source, ks_source in self.ks.get("sources", {}).items():
            self.sources.append(Source(self, source, ks_source))


@dataclass
class KernelSeries(Base):
    ks: dict
    series: list[Series] = field(default_factory=list)

    def __post_init__(self):
        # Parse the kernelseries data
        self.series = []
        for series, ks_series in self.ks.items():
            if ks_series.get("codename"):
                self.series.append(Series(series, ks_series))

    @classmethod
    def load(cls):
        # Create the cache directory
        # if not os.path.exists(os.path.dirname(KS_CACHE)):
        #     os.mkdir(os.path.dirname(KS_CACHE))

        # Load data from cache if the cache is not older than 1 day
        loaded_from_cache = False
        if os.path.exists(KS_CACHE) and os.stat(KS_CACHE).st_mtime > (time.time() - 86400):
            ks = load_from_file(KS_CACHE)
            if ks:
                loaded_from_cache = True

        # Load data from URL and save to cache
        if not loaded_from_cache:
            ks = load_from_url(KS_URL)
            if ks:
                save_to_file(KS_CACHE, ks)

        return cls(ks=ks)
