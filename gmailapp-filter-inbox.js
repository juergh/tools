// Note to self: Define a catch-all filter in the Gmail UI:
//   if hasTheWords "-is:spam" and Size greater than 0 Bytes then
//     skipTheInbox
//     applyTheLabel "00-Inbox"

function filter_inbox() {

    // All messages with this label are filtered
    const FILTER_LABEL = "00-Inbox"

    // Filter rules
    const FILTERS = [
        // From
        ["from.includes('jira@warthogs.atlassian.net')",             "Canonical/Jira"],
        ["from.includes('noreply+ckctreview-bot@canonical.com')",    "Canonical/Bots/ckctreview-bot"],
        ["from.includes('noreply+forgejo-bot@canonical.com')",       "Canonical/Forgejo"],
        ["from.includes('kernel-esm-reviews@groups.canonical.com')", "Mailing List/Canonical/canonical-kernel-esm"],

        // To
        ["to.includes('kernel-team@lists.ubuntu.com')", "Mailing List/Ubuntu/kernel-team"],

        // List-Id
        ["list_id.includes('canonical.github.com')",    "Canonical/Bots/github"],
        ["list_id.includes('discourse.ubuntu.com')",    "Canonical/Discourse"],
        ["list_id.includes('discourse.canonical.com')", "Canonical/Discourse"],

        // Body
        ["body.includes('Launchpad-Message-For: canonical-kernel-crankers')",      "Launchpad-Message-For/canonical-kernel-crankers"],
        ["body.includes('Launchpad-Message-For: canonical-kernel-esm')",           "Launchpad-Message-For/canonical-kernel-esm"],
        ["body.includes('Launchpad-Message-For: canonical-kernel-private')",       "Launchpad-Message-For/canonical-kernel-private"],
        ["body.includes('Launchpad-Message-For: canonical-kernel-rt')",            "Launchpad-Message-For/canonical-kernel-rt"],
        ["body.includes('Launchpad-Message-For: canonical-kernel-security-team')", "Launchpad-Message-For/canonical-kernel-security-team"],
        ["body.includes('Launchpad-Message-For: canonical-kernel-team')",          "Launchpad-Message-For/canonical-kernel-team"],
        ["body.includes('Launchpad-Message-For: canonical-livepatch-kernel')",     "Launchpad-Message-For/canonical-livepatch-kernel"],
        ["body.includes('Launchpad-Message-For: juergh')",                         "Launchpad-Message-For/juergh"],


        ["body.includes('Launchpad-Message-For: ')",                         "Launchpad-Message-For"],
        ["to.includes('kernel-team-bot@canonical.com')",                     "Canonical/Bots/kernel-team-bot"],
        ["to.includes('kernel-team-bot+ancillary@canonical.com')",           "Canonical/Bots/kernel-team-bot"],
        ["to.includes('kernel-team-bot+ubuntu-kernel-gitea@canonical.com')", "Canonical/Bots/kernel-team-bot"],
    ];

    /* --------------------------------------------------------------------------------------------------------------------------------- */

    // Get all user labels
    var labels = {};
    for (const label of GmailApp.getUserLabels()) {
        labels[label.getName()] = label
    }

    // Walk through 50 messages with the filter label
    for (const thread of GmailApp.search(`label:"${FILTER_LABEL}"`, 0, 50)) {
        if (thread.isInSpam()) {
            // Ignore spam
            thread.removeLabel(labels[FILTER_LABEL]);
            continue;
        }

        const message = thread.getMessages()[0];

        const from = message.getFrom().toLowerCase();
        const to = message.getTo().toLowerCase();
        const subject = message.getSubject().toLowerCase();
        const body = message.getPlainBody();

        const list_id = message.getHeader("List-Id");

        // Add a single label based on the filter rules
        var labeled = false;
        for (const filter of FILTERS) {
            if (eval(filter[0])) {
                thread.addLabel(labels[filter[1]]);
                labeled = true;
                break;
            }
        }

        thread.removeLabel(labels[FILTER_LABEL]);
        if (!labeled) {
            thread.moveToInbox();
        }
    }
}
