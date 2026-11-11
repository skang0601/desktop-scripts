// keyd's GNOME extension (data/gnome-extension-45 in keyd 2.6.0), with three
// differences:
//   - It does not start or kill keyd-application-mapper; the systemd user unit
//     keyd-application-mapper.service owns the mapper.
//   - It reports the overview as the window class "gnome-shell-overview". The
//     overview is not a window, so without this the mapper keeps applying the
//     last window's app.conf section to the overview's search entry.
//   - Its signal handlers are disconnected on disable.
//
// The mapper reads "<class>\t<title>\n" lines from $XDG_RUNTIME_DIR/keyd.fifo.

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import Gio from 'gi://Gio';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

let file = Gio.File.new_for_path(makePipe());
let pipe = file.append_to_async(0, 0, null, on_pipe_open);

function makePipe() {
	let runtime_dir = GLib.getenv('XDG_RUNTIME_DIR');
	if (!runtime_dir)
		runtime_dir = '/run/user/'+new TextDecoder().decode(
			GLib.spawn_command_line_sync('id -u')[1]
		).trim();

	let path = runtime_dir + '/keyd.fifo';
	GLib.spawn_command_line_sync('mkfifo ' + path);

	return path;
}

function send(msg) {
	if (!pipe)
		return;

	try {
		pipe.write(msg, null);
	} catch {
		log('pipe closed, reopening...');
		pipe = null;
		file.append_to_async(0, 0, null, on_pipe_open);
	}
}

function on_pipe_open(file, res) {
	log('pipe opened');
	pipe = file.append_to_finish(res);
}

function sendFocus() {
	const win = global.display.focus_window;
	const cls = win ? win.get_wm_class() : 'root';
	const title = win ? win.get_title() : '';

	send(`${cls}	${title}\n`);
}

export default class KeydExtension extends Extension {
	enable() {
		Shell.WindowTracker.get_default().connectObject(
			'notify::focus-app', () => {
				if (!Main.overview.visible)
					sendFocus();
			},
			this
		);

		// Leaving the overview for the window that was already focused emits no
		// focus-app change, so the focus is resent when it closes.
		Main.overview.connectObject(
			'showing', () => send('gnome-shell-overview	\n'),
			'hidden', () => sendFocus(),
			this
		);

		Main.layoutManager.connectObject(
			'system-modal-opened', () => {
				send(`system-modal	${global.stage.get_title()}\n`);
			},
			this
		);
	}

	disable() {
		Shell.WindowTracker.get_default().disconnectObject(this);
		Main.overview.disconnectObject(this);
		Main.layoutManager.disconnectObject(this);
	}
}
