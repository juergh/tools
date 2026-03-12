function filter_inbox() {

    // All messages with this label are filtered
    const FILTER_LABEL = "00-Inbox"

    // Filter rules
    const FILTERS = [
        // From
        ["from", "jira@warthogs.atlassian.net", "Canonical/Jira"],
        ["from", "noreply+ckctreview-bot@canonical.com", "Canonical/Bots/ckctreview-bot"],
        ["from", "noreply+forgejo-bot@canonical.com", "Canonical/Forgejo"],

        // To
        ["to", "kernel-team@lists.ubuntu.com", "Mailing List/Ubuntu/kernel-team"],

        // List-ID
        ["list-id", "canonical.github.com", "Canonical/Bots/github"],
        ["list-id", "discourse.ubuntu.com", "Canonical/Discourse"],
        ["list-id", "discourse.canonical.com", "Canonical/Discourse"],

        // Body
        ["body", "Launchpad-Message-For: canonical-kernel-crankers", "Launchpad-Message-For/canonical-kernel-crankers"],
        ["body", "Launchpad-Message-For: canonical-kernel-esm", "Launchpad-Message-For/canonical-kernel-esm"],
        ["body", "Launchpad-Message-For: canonical-kernel-private", "Launchpad-Message-For/canonical-kernel-private"],
        ["body", "Launchpad-Message-For: canonical-kernel-rt", "Launchpad-Message-For/canonical-kernel-rt"],
        ["body", "Launchpad-Message-For: canonical-kernel-rt", "Launchpad-Message-For/canonical-kernel-rt"],
        ["body", "Launchpad-Message-For: canonical-kernel-security-team", "Launchpad-Message-For/canonical-kernel-security-team"],
        ["body", "Launchpad-Message-For: canonical-kernel-team", "Launchpad-Message-For/canonical-kernel-team"],
        ["body", "Launchpad-Message-For: canonical-livepatch-kernel", "Launchpad-Message-For/canonical-livepatch-kernel"],
        ["body", "Launchpad-Message-For: juergh", "Launchpad-Message-For/juergh"],


        ["body", "Launchpad-Message-For: ", "Launchpad-Message-For"],
        ["to", "kernel-team-bot@canonical.com", "Canonical/Bots/kernel-team-bot"],
        ["to", "kernel-team-bot+ancillary@canonical.com", "Canonical/Bots/kernel-team-bot"],
    ];

    /* --------------------------------------------------------------------------------------------------------------------------- */

    // Get all user labels
    var labels = {};
    for (const label of GmailApp.getUserLabels()) {
        labels[label.getName()] = label
    }

    // Walk through 50 messages with the "__Inbox__" label
    var threads = GmailApp.search(`label:"${FILTER_LABEL}"`, 0, 50);

    for (const thread of threads) {
        const message = thread.getMessages()[0];

        const from = message.getFrom().toLowerCase();
        const to = message.getTo().toLowerCase();
        const subject = message.getSubject().toLowerCase();
        const body = message.getPlainBody();

        const listID = message.getHeader("List-Id");

        // Add a single label based on the filter rules
        var labeled = false;
        for (const filter of FILTERS) {
            switch (filter[0]) {
            case "from":
                if (from.includes(filter[1])) {
                    thread.addLabel(labels[filter[2]]);
                    labeled = true;
                }
                break;
            case "to":
                if (to.includes(filter[1])) {
                    thread.addLabel(labels[filter[2]]);
                    labeled = true;
                }
                break;
            case "subject":
                if (subject.includes(filter[1])) {
                    thread.addLabel(labels[filter[2]]);
                    labeled = true;
                }
                break;
            case "body":
                if (body.includes(filter[1])) {
                    thread.addLabel(labels[filter[2]]);
                    labeled = true;
                }
                break;
            case "list-id":
                if (listID.includes(filter[1])) {
                    thread.addLabel(labels[filter[2]]);
                    labeled = true;
                }
                break;
            }

            if (labeled) {
                break;
            }
        }

        thread.removeLabel(labels[FILTER_LABEL]);
        if (!labeled) {
            thread.moveToInbox();
        }
    }
}
