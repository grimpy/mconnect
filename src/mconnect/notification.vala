/**
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * AUTHORS
 * Maciek Borzecki <maciek.borzecki (at] gmail.com>
 */
using Gee;

class NotificationHandler : Object, PacketHandlerInterface {

    private const string NOTIFICATION = "kdeconnect.notification";

    private HashMap<string, Notify.Notification> _pending_notifications;

    public string get_pkt_type () {
        return NOTIFICATION;
    }

    private NotificationHandler () {
        _pending_notifications = new HashMap<string, Notify.Notification>();
    }

    public static NotificationHandler instance () {
        return new NotificationHandler ();
    }

    public void use_device (Device dev) {
        dev.message.connect (this.message);
    }

    public void release_device (Device dev) {
        dev.message.disconnect (this.message);
    }

    public void message (Device dev, Packet pkt) {
        if (pkt.pkt_type != NOTIFICATION) {
            return;
        }
        debug ("got notification packet");
        string tempfile = null;
        if (pkt.payload != null) {
            try {
                GLib.FileUtils.open_tmp("mconnect-icon-XXXXXX", out tempfile);
            } catch (Error e) {
                critical ("failed to create tmp file: %s", e.message);
                this.handle_pkt(dev, pkt, null);
                return;
            }
            debug ("file: %s size: %s", tempfile, format_size (pkt.payload.size));

            var t = new DownloadTransfer (
                dev,
                new InetSocketAddress (dev.host,
                                       (uint16) pkt.payload.port),
                pkt.payload.size,
                tempfile);

            Core.instance ().transfer_manager.push_job (t);
            t.finished.connect ((n) => {
                this.handle_pkt(dev, pkt, tempfile);
                g_free(tempfile);
            });
            t.start_async.begin ();
        } else {
            this.handle_pkt(dev, pkt, null);
        }
    }


    public void handle_pkt (Device dev, Packet pkt, string? filename) {
        // get application ID
        string id = pkt.body.get_string_member ("id");

        // dialer notifications are handled by telephony plugin
        if (id.match_string ("com.android.dialer", false) == true)
            return;

        // maybe it's a notification about a notification being
        // cancelled
        if (pkt.body.has_member ("isCancel") == true &&
            pkt.body.get_boolean_member ("isCancel") == true) {
            debug ("message cancels notification %s", id);
            if (_pending_notifications.has_key (id) == true) {
                // cancel out pending notifications
                Notify.Notification notif = _pending_notifications.@get (id);
                if (notif != null) {
                    _pending_notifications.unset (id);
                    try {
                        notif.close ();
                    } catch (Error e) {
                        critical ("error closing notification: %s", e.message);
                    }
                }
            }
            return;
        }

        // check if notification is already known, if so don't show
        // anything
        if (_pending_notifications.has_key (id) == true) {
            debug ("notification %s is known, ignore", id);
            return;
        }
        debug ("new notification %s", id);

        // other notifications
        if (pkt.body.has_member ("appName") == false ||
            pkt.body.has_member ("ticker") == false)
            return;

        string app = pkt.body.get_string_member ("appName");
        string ticker = pkt.body.get_string_member ("ticker");

        // skip empty notifications
        if (ticker.length == 0)
            return;

        DateTime time = null;
        // check if time was provided, prepend to ticker
        if (pkt.body.has_member ("time") == true) {
            string timestr = pkt.body.get_string_member ("time");
            int64 t = int64.parse (timestr);
            // time in ms since Epoch, convert to seconds
            t /= 1000;
            time = new DateTime.from_unix_local (t);
        } else {
            time = new DateTime.now_local ();
        }
        // format the body of notification, so that a time information
        // is included
        if (time != null)
            ticker = "%s %s".printf (time.format ("%X"),
                                     ticker);

        GLib.message ("notification from %s: %s", app, ticker);

        var notif = new Notify.Notification (app, ticker,
                                             "phone");

        // Set Image
        if (filename != null) {
            File file = File.new_for_path (filename);
            try {
                FileInputStream @is = file.read ();
                DataInputStream dis = new DataInputStream (@is);
                try {
                    notif.set_icon_from_pixbuf(new Gdk.Pixbuf.from_stream( dis ));
                    file.@delete();
                } catch (Error e) {
                    critical ("failed to load image data: %s", e.message);
                }
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
        }
        try {
            // react to closed signal
            notif.closed.connect ((n) => {
                this.handle_closed_notification (id);
            });
            notif.show ();
            _pending_notifications.@set (id, notif);
        } catch (Error e) {
            critical ("failed to show notification: %s", e.message);
        }
    }

    private void handle_closed_notification (string id) {
        debug ("notification %s closed by user", id);
        if (_pending_notifications.has_key (id) == true) {
            _pending_notifications.unset (id);
        }
    }
}
