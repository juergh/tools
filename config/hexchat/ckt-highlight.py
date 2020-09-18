#!/usr/bin/env python3

__module_name__ = "ckt-highlight"
__module_version__ = "0.0.1"
__module_description__ = "Script to highlight messages with special characters (e.g. @all)"

import hexchat
import re

words2highlight = ["@all", "@here", "@juergh", "@kernel-help", "@kernel"]
regex = re.compile(r"(?<![^\W])(" + '|'.join(words2highlight) + r")\b")

def highlight_cb(word, word_eol, userdata):
    if not regex.search(word_eol[1]):
        return hexchat.EAT_NONE

    # The command "GUI COLOR" changes the channel tab color to:
    #   0) visited
    #   1) new data
    #   2) new message
    #   3) new highlight
    hexchat.command("GUI COLOR 3")

    # Print the highlighted text
    hexchat.emit_print("Channel Msg Hilight", *word)

    return hexchat.EAT_ALL

hexchat.hook_print("Channel Message", highlight_cb)
