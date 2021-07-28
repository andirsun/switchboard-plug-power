/*
 * Copyright (c) 2011-2018 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA  02110-1301, USA.
 */

public class Power.HardwareView : Granite.SimpleSettingsPage {
    public Battery battery { get; private set; }
    public Gtk.Stack stack { get; private set; }

    private const string NO_PERMISSION_STRING = _("You do not have permission to change this");
    private const string SETTINGS_DAEMON_NAME = "org.gnome.SettingsDaemon.Power";
    private const string SETTINGS_DAEMON_PATH = "/org/gnome/SettingsDaemon/Power";

    private Gtk.Scale scale;
    private PowerSettings screen;
    private PowerSupply power_supply;

    private enum PowerActionType {
        BLANK,
        SUSPEND,
        SHUTDOWN,
        HIBERNATE,
        INTERACTIVE,
        NOTHING,
        LOGOUT
    }

		public HardwareView () {
			Object (
					icon_name: "application-x-firmware",
					title: _("Hardware")
			);
		}

    construct {
				content_area.row_spacing = 6;
        margin_bottom = 12;

        var label_size = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);

        settings = new GLib.Settings ("org.gnome.settings-daemon.plugins.power");

        battery = new Battery ();
        power_supply = new PowerSupply ();

        if (lid_detect ()) {
            var lid_closed_label = new Gtk.Label (_("When lid is closed:"));
            lid_closed_label.halign = Gtk.Align.END;
            lid_closed_label.xalign = 1;

            var lid_closed_box = new LidCloseActionComboBox (false);

            var lid_dock_label = new Gtk.Label (_("When lid is closed with external monitor:"));
            lid_dock_label.halign = Gtk.Align.END;
            lid_dock_label.xalign = 1;

            var lid_dock_box = new LidCloseActionComboBox (true);

            label_size.add_widget (lid_closed_label);
            label_size.add_widget (lid_dock_label);

            var lock_image = new Gtk.Image.from_icon_name ("changes-prevent-symbolic", Gtk.IconSize.BUTTON);
            lock_image.sensitive = false;
            lock_image.tooltip_text = NO_PERMISSION_STRING;

            var lock_image2 = new Gtk.Image.from_icon_name ("changes-prevent-symbolic", Gtk.IconSize.BUTTON);
            lock_image2.sensitive = false;
            lock_image2.tooltip_text = NO_PERMISSION_STRING;

            content_area.attach (lid_closed_label, 0, 5, 1, 1);
            content_area.attach (lid_closed_box, 1, 5, 1, 1);
            content_area.attach (lock_image2, 2, 5, 1, 1);
            content_area.attach (lid_dock_label, 0, 6, 1, 1);
            content_area.attach (lid_dock_box, 1, 6, 1, 1);
            content_area.attach (lock_image, 2, 6, 1, 1);

            var lock_button = new Gtk.LockButton (get_permission ());

            var permission_label = new Gtk.Label (_("Some settings require administrator rights to be changed"));

            var permission_infobar = new Gtk.InfoBar ();
            permission_infobar.message_type = Gtk.MessageType.INFO;
            permission_infobar.get_content_area ().add (permission_label);

            var area_infobar = permission_infobar.get_action_area () as Gtk.Container;
            area_infobar.add (lock_button);

            add (permission_infobar);

            var permission = get_permission ();
            permission.bind_property ("allowed", lid_closed_box, "sensitive", GLib.BindingFlags.SYNC_CREATE);
            permission.bind_property ("allowed", lid_closed_label, "sensitive", GLib.BindingFlags.SYNC_CREATE);
            permission.bind_property ("allowed", lid_dock_box, "sensitive", GLib.BindingFlags.SYNC_CREATE);
            permission.bind_property ("allowed", lid_dock_label, "sensitive", GLib.BindingFlags.SYNC_CREATE);
            permission.bind_property ("allowed", lock_image, "visible", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.INVERT_BOOLEAN);
            permission.bind_property ("allowed", lock_image2, "visible", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.INVERT_BOOLEAN);
            permission.bind_property ("allowed", permission_infobar, "revealed", GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.INVERT_BOOLEAN);
        }

        var power_label = new Gtk.Label (_("Power button:"));
        power_label.halign = Gtk.Align.END;
        power_label.xalign = 1;

        var power_combobox = new ActionComboBox ("power-button-action");

        content_area.attach (power_label, 0, 4, 1, 1);
        content_area.attach (power_combobox, 1, 4, 1, 1);

        
        show_all ();

        label_size.add_widget (power_label);
    }

    private static bool lid_detect () {
        var interface_path = File.new_for_path ("/proc/acpi/button/lid/");

        try {
            var enumerator = interface_path.enumerate_children (
            GLib.FileAttribute.STANDARD_NAME,
            FileQueryInfoFlags.NONE);
            FileInfo lid;
            if ((lid = enumerator.next_file ()) != null) {
                debug ("Detected lid switch");
                return true;
            }

            enumerator.close ();

        } catch (GLib.Error err) {
            warning ("%s", err.message); //Not critical as this eventuality is dealt with
        }

        return false;
    }

    private void on_scale_value_changed () {
        var val = (int) scale.get_value ();
        ((DBusProxy)screen).g_properties_changed.disconnect (on_screen_properties_changed);
        screen.brightness = val;
        ((DBusProxy)screen).g_properties_changed.connect (on_screen_properties_changed);
    }

    private void on_screen_properties_changed (Variant changed_properties, string[] invalidated_properties) {
        var changed_brightness = changed_properties.lookup_value ("Brightness", new VariantType ("i"));
        if (changed_brightness != null) {
            var val = screen.brightness;
            scale.value_changed.disconnect (on_scale_value_changed);
            scale.set_value (val);
            scale.value_changed.connect (on_scale_value_changed);
        }
    }
}