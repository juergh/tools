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
-- Move mails older than 'age' from 'source_folder' to 'target_folder'
--
function move_mail(account, source_folder, target_folder, age)
   local _, _target_mbox, _target_msgs, _mboxes, _subfolders, _old_msgs

   print('Folder: ' .. source_folder)

   -- Skip folders that we don't want to process
   if source_folder == target_folder or source_folder == '[Gmail]' then
      print('Skipping folder (blacklisted)')
      return
   end

   -- Create the target mailbox for the provided account and source folder
   if source_folder == '' then
      _target_mbox = target_folder
   else
      _target_mbox = target_folder .. '/' .. source_folder
   end
   _target_msgs, _, _, _ = account[_target_mbox]:check_status()
   if _target_msgs == -1 then
      print('Creating target mailbox: ' .. _target_mbox)
      account:create_mailbox(_target_mbox)
   end

   -- Get all mailboxes and subfolders of the provided account and source folder
   _mboxes, _subfolders = account:list_all(source_folder)

   -- Cycle through the mailboxes and archive mails older than 'age'
   for _, _mbox in ipairs(_mboxes) do
      print('Mailbox: ' .. _mbox)

      -- Skip mailboxes that we don't want to archive
      if _mbox == target_folder or _mbox == 'Drafts' or _mbox == 'Trash' then
	 print('Skipping mailbox (blacklisted)')
	 goto continue1
      end

      -- Get the list of mails older than 'age' from the current mailbox
      _old_msgs = account[_mbox]:is_older(age)

      -- The list is empty
      if _old_msgs[1] == nil then
	 print('Skipping mailbox (no mails to archive)')
	 goto continue1
      end

      print('Archiving mails in \'' .. _mbox .. '\' (older than ' .. age .. ' days)')
      _old_msgs:move_messages(account[target_folder .. '/' .. _mbox])

      ::continue1::
   end

   -- Cycle through the subfolders and archive them recursively
   for _, _folder in ipairs(_subfolders) do
      move_mail(account, _folder, target_folder, age)
   end
end
