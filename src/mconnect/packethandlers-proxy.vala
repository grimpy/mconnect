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

class PacketHandlersProxy : Object {

    public static PacketHandlerInterfaceProxy ? new_device_capability_handler (
        Device dev,
        string cap,
        PacketHandlerInterface iface) {

        switch (iface.get_pkt_type ()) {
        case BatteryHandler.BATTERY: {
            return new BatteryHandlerProxy.for_device_handler (dev, iface);
        }
        case PingHandler.PING: {
            return new PingHandlerProxy.for_device_handler (dev, iface);
        }
        case ShareHandler.SHARE: {
            return new ShareHandlerProxy.for_device_handler (dev, iface);
        }
        case TelephonyHandler.TELEPHONY: {
            return new TelephonyHandlerProxy.for_device_handler (dev, iface);
        }
        case FindMyPhoneHandler.FIND_MY_PHONE: {
            return new FindMyPhoneHandlerProxy.for_device_handler (dev, iface);
        }
        default:
            warning ("cannot register bus handler for %s",
                     iface.get_pkt_type ());
            break;
        }
        return null;
    }
}
