#!/usr/bin/lua
--
-- Helper functions for use with imapfilter
--

-------------------------------------------------------------------------------
-- Return a password from the password store
--
function show_pass(pass_name)
   local _, _output

   _, _output = pipe_from('pass show ' .. pass_name)  -- luacheck: ignore pipe_from
   return _output
end

-------------------------------------------------------------------------------
-- Move 'messages' to 'target_mailbox'
--
function move_mail(account, messages, target_mailbox)
   local _, _target_messages

   -- Check if there are messages to move
   if messages[1] == nil then
      print('Skipping (no mails to move)')
      return
   end

   -- Create the target mailbox if necessary
   _target_messages, _, _, _ = account[target_mailbox]:check_status()
   if _target_messages == -1 then
      print('Creating target mailbox')
      account:create_mailbox(target_mailbox)
   end

   -- Move the mails
   messages:move_messages(account[target_mailbox])
end

-------------------------------------------------------------------------------
-- Recursively move messages older than 'age' days from 'source_folder' to
-- 'target_root', preserving the folder hierarchy
--
function move_mail_is_older_recursive(account, source_folder, target_root, age)
   local _source_mailboxes, _source_subfolders, _target_mailbox

   print('Move mail (is_older_recursive)')
   print('  Age:    ' .. age)
   print('  Folder: ' .. source_folder)

   -- Skip folders that we don't want to process
   if source_folder == target_root or source_folder == '[Gmail]' then
      print('  Skipping folder (blacklisted)')
      return
   end

   -- Get all mailboxes and subfolders of the provided account and source
   -- folder
   _source_mailboxes, _source_subfolders = account:list_all(source_folder)

   -- Cycle through the mailboxes and move mails older than 'age'
   for _, _source_mailbox in ipairs(_source_mailboxes) do
      _target_mailbox = target_root .. '/' .. _source_mailbox
      print('    Source mailbox: ' .. _source_mailbox)

      -- Skip mailboxes that we don't want to archive
      if (_source_mailbox == target_root or _source_mailbox == 'Drafts' or
	  _source_mailbox == 'Trash') then
	 print('    Skipping mailbox (blacklisted)')
	 goto continue1
      end

      print('    Target mailbox: ' .. _target_mailbox)

      -- Move the messages
      move_mail_is_older(account, _source_mailbox, _target_mailbox, age, 1)

      ::continue1::
   end

   -- Cycle through the source subfolders
   for _, _source_subfolder in ipairs(_source_subfolders) do
      move_mail_is_older_recursive(account, _source_subfolder, target_root,
				   age)
   end
end

-------------------------------------------------------------------------------
-- Move messages older than 'age' days from 'source_mailbox' to
-- 'target_mailbox'
--
function move_mail_is_older(account, source_mailbox, target_mailbox, age,
			    quiet)
   local _messages

   if quiet == nil then
      print('Move mail (is_older)')
      print('  Age:            ' .. age)
      print('  Source mailbox: ' .. source_mailbox)
      print('  Target mailbox: ' .. target_mailbox)
   end

   -- Fetch the mails that are older than 'age' days and move them
   _messages = account[source_mailbox]:is_older(age)
   move_mail(account, _messages, target_mailbox)
end

-------------------------------------------------------------------------------
-- Move messages  that contain 'text' in their subjects from 'source_mailbox'
-- to 'target_mailbox'
--
function move_mail_contain_subject(account, source_mailbox, target_mailbox,
				   text, quiet)
   local _messages

   if quiet == nil then
      print('Move mail (contain_subject)')
      print('  Text:           ' .. text)
      print('  Source mailbox: ' .. source_mailbox)
      print('  Target mailbox: ' .. target_mailbox)
   end

   -- Fetch the mails that contain 'text' in their subjects and move them
   _messages = account[source_mailbox]:contain_subject(text)
   move_mail(account, _messages, target_mailbox)
end
