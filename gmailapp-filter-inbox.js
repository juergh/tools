//
// Note to self: Define two filters in the Gmail UI in the exact order:
//
// 1. Matches: from:(@bugs.launchpad.net)
//    Do this: Never send it to Spam
//
// 2. Matches: from:(*@)
//    Do this: Skip Inbox, Apply label "00-Inbox"
//

function filter_inbox() {

    // All messages with this label are filtered
    const FILTER_LABEL = "00-Inbox"

    // Filter rules
    const FILTERS = [
        // Trash
        [({subject}) => subject.includes(' abi-testing: ABI testing report'),        "Trash"],
        [({subject}) => subject.includes(' -proposed tracker'),                      "Trash"],
        [({subject}) => subject.includes(' Workflow done!'),                         "Trash"],
        [({subject}) => subject.includes(' uploaded (ABI bump)'),                    "Trash"],
        [({subject}) => subject.includes(' Live Kernel Patching release tracker'),   "Trash"],
        [({subject}) => subject.includes(' build of livepatch-linux-'),              "Trash"],
        [({to}) => to.includes('kernel-team-bot+ancillary@canonical.com'),           "Trash"],
        [({to}) => to.includes('kernel-team-bot@canonical.com'),                     "Trash"],
        [({to}) => to.includes('kernel-team-bot+ubuntu-kernel-gitea@canonical.com'), "Trash"],

        // Pre-filter
        [({subject}) => subject.includes('The Daily Bug Report for 20'),         "Canonical/Bugs"],
        [({subject}) => subject.includes('SFDC'),                                "Canonical/SalesForce"],
        [({body}) => body.includes('Launchpad-Subscription: linux-firmware'),    "Launchpad-Message-For/juergh"],

        // From
        [({from}) => from.includes('noreply+ckctreview-bot@canonical.com'), "Canonical/Bots"],
        [({from}) => from.includes('prod-kernel-team-janitor'),             "Canonical/Bots"],
        [({from}) => from.includes('noreply+forgejo-bot@canonical.com'),    "Canonical/Forgejo"],
        [({from}) => from.includes('jira@warthogs.atlassian.net'),          "Canonical/Jira"],

        // List-Id (Canonical)
        [({list_id}) => list_id.includes('canonical.github.com'),                    "Canonical/Github"],
        [({list_id}) => list_id.includes('discourse.canonical.com'),                 "Canonical/Discourse"],
        [({list_id}) => list_id.includes('kernel-esm-reviews.groups.canonical.com'), "Mailing List/Canonical/canonical-kernel-esm"],
        [({list_id}) => list_id.includes('warthogs.lists.canonical.com'),            "Mailing List/Canonical/warthogs"],

        // List-Id (Ubuntu)
        [({list_id}) => list_id.includes('discourse.ubuntu.com'),               "Canonical/Discourse"],
        [({list_id}) => list_id.includes('devel-permissions.lists.ubuntu.com'), "Mailing List/Ubuntu/devel-permissions"],
        [({list_id}) => list_id.includes('kernel-team.lists.ubuntu.com'),       "Mailing List/Ubuntu/kernel-team"],
        [({list_id}) => list_id.includes('ubuntu-devel.lists.ubuntu.com'),      "Mailing List/Ubuntu/ubuntu-devel"],
        [({list_id}) => list_id.includes('ubuntu-release.lists.ubuntu.com'),    "Mailing List/Ubuntu/ubuntu-release"],

        // Body
        [({body}) => body.includes('Launchpad-Message-For: canonical-kernel-crankers'),      "Launchpad-Message-For/canonical-kernel-crankers"],
        [({body}) => body.includes('Launchpad-Message-For: canonical-kernel-esm'),           "Launchpad-Message-For/canonical-kernel-esm"],
        [({body}) => body.includes('Launchpad-Message-For: canonical-kernel-private'),       "Launchpad-Message-For/canonical-kernel-private"],
        [({body}) => body.includes('Launchpad-Message-For: canonical-kernel-rt'),            "Launchpad-Message-For/canonical-kernel-rt"],
        [({body}) => body.includes('Launchpad-Message-For: canonical-kernel-security-team'), "Launchpad-Message-For/canonical-kernel-security-team"],
        [({body}) => body.includes('Launchpad-Message-For: canonical-kernel-team'),          "Launchpad-Message-For/canonical-kernel-team"],
        [({body}) => body.includes('Launchpad-Message-For: canonical-livepatch-kernel'),     "Launchpad-Message-For/canonical-livepatch-kernel"],
        [({body}) => body.includes('Launchpad-Message-For: juergh'),                         "Launchpad-Message-For/juergh"],

        // Post-filter
        [({body}) => body.includes('Launchpad-Message-For: '), "Launchpad-Message-For"],
    ];

    /* --------------------------------------------------------------------------------------------------------------------------------- */

    // Get all user labels
    const labels = {};
    for (const label of GmailApp.getUserLabels()) {
        labels[label.getName()] = label
    }

    // Batch buckets
    const inboxThreads = [];
    const trashThreads = [];
    const labelThreads = {};
    const removeLabelThreads = [];

    // 1. Fetch the 100 threads
    const threads = GmailApp.search(`label:"${FILTER_LABEL}"`, 0, 100);
    if (threads.length === 0) {
        return;
    }

    // 2. CRITICAL OPTIMIZATION: Fetch ALL messages for ALL threads in a single API call
    const messages2D = GmailApp.getMessagesForThreads(threads);

    // 3. Loop through the cached data (No API calls inside this loop!)
    for (let i = 0; i < threads.length; i++) {
        const thread = threads[i];
        removeLabelThreads.push(thread);

        if (thread.isInSpam()) {
            continue;
        }

        // Pull the pre-fetched message from our 2D array matrix
        const threadMessages = messages2D[i];
        if (!threadMessages || threadMessages.length === 0) {
            continue;
        }
        const message = threadMessages[0];

        const from = message.getFrom().toLowerCase();
        const to = message.getTo().toLowerCase();
        const subject = message.getSubject();
        const body = message.getPlainBody() || "";
        const list_id = message.getHeader("List-Id") || "";

        // Find the first filter rule that matches
        let dest = "Inbox";
        for (const filter of FILTERS) {
            if (filter[0]({from, to, subject, body, list_id})) {
                dest = filter[1];
                break;
            }
        }

        console.log(dest + " -- " + subject);

        switch (dest) {
        case "Inbox":
            inboxThreads.push(thread);
            break;
        case "Trash":
            trashThreads.push(thread);
            break;
        default:
            if (!labelThreads[dest]) {
                labelThreads[dest] = [];
            }
            labelThreads[dest].push(thread);
            break;
        }
    }

    // Batch-move threads
    if (inboxThreads.length) {
        console.log("Move threads to Inbox")
        GmailApp.moveThreadsToInbox(inboxThreads);
    }
    if (trashThreads.length) {
        console.log("Move threads to Trash")
        GmailApp.moveThreadsToTrash(trashThreads);
    }
    for (const [dest, threads] of Object.entries(labelThreads)) {
        console.log("Label threads with " + dest)
        if (!labels[dest]) {
            console.error(`Label not found: "${dest}"`);
            continue;
        }
        labels[dest].addToThreads(threads);
    }

    // Batch-remove the filter label
    if (removeLabelThreads.length) {
        labels[FILTER_LABEL].removeFromThreads(removeLabelThreads);
    }
}
