// Note to self: Define a catch-all filter in the Gmail UI:
//   if hasTheWords "-is:spam" and Size greater than 0 Bytes then
//     skipTheInbox
//     applyTheLabel "00-Inbox"

function filter_inbox() {

    // All messages with this label are filtered
    const FILTER_LABEL = "00-Inbox"

    // Filter rules
    const FILTERS = [
        // Trash
        ["subject.includes('abi-testing: ABI testing report')", "Trash"],

        // Pre-filter
        ["subject.includes('The Daily Bug Report for 20')",         "Canonical/Bugs"],
        ["subject.includes('SFDC')",                                "Canonical/SalesForce"],
        ["body.includes('Launchpad-Subscription: linux-firmware')", "Launchpad-Message-For/juergh"],

        // From
        ["from.includes('jira@warthogs.atlassian.net')",             "Canonical/Jira"],
        ["from.includes('noreply+ckctreview-bot@canonical.com')",    "Canonical/Bots"],
        ["from.includes('noreply+forgejo-bot@canonical.com')",       "Canonical/Forgejo"],
        ["from.includes('kernel-esm-reviews@groups.canonical.com')", "Mailing List/Canonical/canonical-kernel-esm"],

        // To
        ["to.includes('kernel-team@lists.ubuntu.com')", "Mailing List/Ubuntu/kernel-team"],

        // List-Id
        ["list_id.includes('canonical.github.com')",    "Canonical/Github"],
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

        // Post-filter
        ["body.includes('Launchpad-Message-For: ')",                         "Launchpad-Message-For"],
        ["to.includes('kernel-team-bot@canonical.com')",                     "Canonical/Bots"],
        ["to.includes('kernel-team-bot+ancillary@canonical.com')",           "Canonical/Bots"],
        ["to.includes('kernel-team-bot+ubuntu-kernel-gitea@canonical.com')", "Canonical/Bots"],
    ];

    /* --------------------------------------------------------------------------------------------------------------------------------- */

    // Get all user labels
    var labels = {};
    for (const label of GmailApp.getUserLabels()) {
        labels[label.getName()] = label
    }

    // Walk through 100 messages with the filter label
    for (const thread of GmailApp.search(`label:"${FILTER_LABEL}"`, 0, 100)) {
        if (thread.isInSpam()) {
            // Ignore spam
            thread.removeLabel(labels[FILTER_LABEL]);
            continue;
        }

        const message = thread.getMessages()[0];

        const from = message.getFrom().toLowerCase();
        const to = message.getTo().toLowerCase();
        const subject = message.getSubject();
        const body = message.getPlainBody();

        const list_id = message.getHeader("List-Id");

        // Find the first filter rule that matches
        var action = "Inbox";
        for (const filter of FILTERS) {
            if (eval(filter[0])) {
                action = filter[1];
                break;
            }
        }

        thread.removeLabel(labels[FILTER_LABEL]);

        switch (action) {
        case "Inbox":
            thread.moveToInbox();
            break;
        case "Trash":
            thread.moveToTrash();
            break;
        default:
            thread.addLabel(labels[action]);
            break;
        }
    }
}
