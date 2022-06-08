#!/usr/bin/lua
--
-- Helper functions for use with imapfilter
--

-------------------------------------------------------------------------------
-- Check if a table contains a given value.

local function has_value(tab, val)
   for _, _val in ipairs(tab) do
      if _val == val then
	 return true
      end
   end
   return false
end

-------------------------------------------------------------------------------
-- Return a password from the password store.

local function get_pass(pass_name)
   local _output

   _, _output = pipe_from('pass show ' .. pass_name)  -- luacheck: ignore
   return _output
end

-------------------------------------------------------------------------------
-- Move 'messages' to 'mailbox'. Create 'mailbox' first if necessary.

local function move_messages(messages, mailbox)
   local _, _messages

   -- Check if there are messages to move
   if messages[1] == nil then
      print('-- Skipping (no messages to move)')
      return
   end

   -- Create the target mailbox if necessary
   _messages, _, _, _ = mailbox:check_status()
   if _messages == -1 then
      print('-- Creating target mailbox ' .. mailbox._mailbox)
      mailbox._account:create_mailbox(mailbox._mailbox)
   end

   -- Move the messages
   print('-- Moving messages to ' .. mailbox._mailbox)
   messages:move_messages(mailbox)
end

-------------------------------------------------------------------------------
-- Return the list of mailboxes in and underneath 'folder'

local function list_all_recursive(account, folder, blacklist, mailboxes)
   local _mailboxes, _subfolders

   if mailboxes == nil then
      mailboxes = {}
   end

   -- Get all mailboxes and subfolders
   _mailboxes, _subfolders = account:list_all(folder)

   -- Cycle through all mailboxes and append them to the list
   for _, _mailbox in ipairs(_mailboxes) do
      if has_value(blacklist, _mailbox) then
	 print('-- Skippping mailbox ' .. _mailbox .. ' (blacklisted)')
      else
	 table.insert(mailboxes, _mailbox)
      end
   end

   -- Cycle through all subfolders recursively
   for _, _subfolder in ipairs(_subfolders) do
      if has_value(blacklist, _subfolder) then
	 print('-- Skippping folder ' .. _subfolder .. ' (blacklisted)')
      else
	 list_all_recursive(account, _subfolder, blacklist, mailboxes)
      end
   end

   return mailboxes
end

-------------------------------------------------------------------------------
-- Archive all messages older than 'age' days

local function archive_messages(account, age)
   local _blacklist, _messages

   -- List of mailboxes/folders to skip
   _blacklist = {'Drafts', 'Queue', 'Trash', '__Archive', '[Gmail]'}

   -- Cycle through all the mailboxes
   for _, _mailbox in ipairs(list_all_recursive(account, '', _blacklist)) do
      print('-- Archiving mailbox ' .. _mailbox)
      _messages = account[_mailbox]:is_older(age)
      move_messages(_messages, account['__Archive/' .. _mailbox])
   end
end

-------------------------------------------------------------------------------
-- Return a list of messages that are members of the same thread. The returned
-- list is an associative array (Lua table) rather than an imapfilter Set() of
-- messages so that the check if a message has already been processed is a
-- simple table lookup rather than a search through a set of messages.

local function _thread_messages(message, thread_list)
   local _mbox, _uid, _key, _message_id

   -- Initialize the list of already processed messages if it's the first call
   -- of this function
   if not thread_list then
      thread_list = {}
   end

   -- Unpack the message
   _mbox, _uid = table.unpack(message)

   -- Check if the current message has already been processed
   _key = _mbox._string .. ':' .. tostring(_uid)
   if thread_list[_key] then
      return thread_list
   end
   thread_list[_key] = message

   -- Debug output
   print('++ ' .. _mbox[_uid]:fetch_field('Subject'))

   -- Process the replies to the current message (children)
   _message_id = _mbox[_uid]:fetch_field('Message-Id'):match('<.+>')
   for _, _msg in ipairs(_mbox:contain_field('In-Reply-To', _message_id)) do
      thread_list = _thread_messages(_msg, thread_list)
   end

   -- Process the messages this message was replied to (parents)
   for _reply_id in _mbox[_uid]:fetch_field('In-Reply-To'):gmatch('<[^>]+>') do
      for _, _msg in ipairs(_mbox:contain_field('Message-Id', _reply_id)) do
         thread_list = _thread_messages(_msg, thread_list)
      end
   end

   return thread_list
end

-------------------------------------------------------------------------------
-- Return all messages in a thread.

local function thread_messages(message)
   local _messages

   _messages = {}
   for _, _msg in pairs(_thread_messages(message)) do
      table.insert(_messages, _msg)
   end

   -- Convert the list of messages to an imapfilter Set()
   return Set(_messages)
end
