local tasl = {}

tasl.state = {
  target_pane = nil
}

tasl.set_target_pane = function (pane)
  tasl.state.target_pane = pane
end

-- list_panes_text is output of 'tmux list-panes -a'
local get_current_tmux_pane_id = function (list_panes_text, tmux_pane_id)
  local tmux_pane_pattern = string.gsub(tmux_pane_id, '%%', '%%%%')  -- escape nightmare
  for l in string.gmatch(list_panes_text, '[^\n]+') do
    if string.find(l, tmux_pane_pattern) then
      local pane_id = string.sub(l, 0, string.find(l, ' ')-1)
      local sessid, winid, paneid = string.match(pane_id, '(%d+):(%d+).(%d+):')
      return sessid, winid, paneid
    end
  end
end

-- Guess is other pane in current window.
local guess_target_pane = function ()
  local proc = assert(spawn('tmux list-panes -a'))
  local pane_text = proc:read('*a')

  local tmux_pane_env = os.getenv('TMUX_PANE')
  if not tmux_pane_env then
    return
  end

  local sessid, winid, paneid = get_current_tmux_pane_id(pane_text, tmux_pane_env)
  local guessed_target_pane = sessid..':'..winid..'.'..math.floor(1-paneid)
  return guessed_target_pane
end

tasl.get_target_pane = function ()
  if tasl.state.target_pane then
    return tasl.state.target_pane
  end

  local guessed_target_pane = guess_target_pane()
  tasl.set_target_pane(guessed_target_pane)
  return guessed_target_pane
end

local selected_text = function ()
  local s, e = buffer.selection_start, buffer.selection_end
  buffer:set_target_range(s, e)
  return buffer.target_text
end

local escape = function (text)
  return text:gsub('"', '\\"'):gsub('[$]', '\\$')
end

local run_commands = function (commands)
  for _,command in ipairs(commands) do
    cmdexit = os.execute(command)
    if not cmdexit then
      return
    end
  end
end

tasl.paste = {}
tasl.paste.text = function (text)
  local text = text or selected_text()
  local escaped_text = escape(text)
  local commands = {
    'tmux set-buffer -b tasl -- "'..tostring(escaped_text)..'"',
    'tmux paste-buffer -d -b tasl -t '..tostring(tasl.get_target_pane())
  }
  run_commands(commands)
end

tasl.paste.python = function (text)
  local text = text or selected_text()
  tasl.paste.text('%cpaste\n')
  tasl.paste.text(tostring(text)..'\n')
  tasl.paste.text('--\n')
end

return tasl
