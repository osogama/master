/* FontConfig.vala
 *
 * Copyright © 2009 - 2014 Jerry Casiano
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author:
 *  Jerry Casiano <JerryCasiano@gmail.com>
 */

namespace FontConfig {

    public class Main : Object {

        public signal void changed (File? file, FileMonitorEvent event);
        public signal void progress (string? message, int processed, int total);

        public Accept accept { get; private set; }
        public Directories dirs { get; private set; }
        public Families families { get; private set; }
        public Properties props { get; private set; }
        public Reject reject { get; private set; }
        public Sources sources { get; private set; }

        FileMonitor? [] monitors = {};

        public Main () {
            accept = new Accept();
            dirs = new Directories();
            props = new Properties();
            reject = new Reject();
            families = new Families();
            sources = new Sources();
            families.progress.connect((m, p, t) => { progress(m, p, t); });
        }

        public void update () {
            enable_user_config(false);
            load_user_fontconfig_files();
            cancel_monitors();
            if (!load_user_font_sources(dirs, sources))
                critical("Failed to register user font sources with FontConfig! User fonts may be unavailable for preview.");
            families.update();
            enable_monitors();
            return;
        }

        public void init () {
            accept.init();
            dirs.init();
            props.init();
            reject.init();
            sources.init();
            this.update();
            return;
        }

        public void cancel_monitors () {
            foreach (var mon in monitors) {
                mon.cancel();
                mon = null;
            }
            return;
        }

        public void enable_monitors () {
            foreach (var dir in list_dirs()) {
                File file = File.new_for_path(dir);
                FileMonitor monitor = file.monitor_directory(FileMonitorFlags.NONE);
                monitor.changed.connect((f, of, ev) => {
                    cancel_monitors();
                    changed(f, ev);
                    monitors = {};
                    enable_monitors();
                });
                monitors += monitor;
            }
            return;
        }

    }

    string get_config_dir () {
        string config_dir = Path.build_filename(Environment.get_user_config_dir(), "fontconfig", "conf.d");
        DirUtils.create_with_parents(config_dir, 0755);
        return config_dir;
    }

    /*
     * This function loads any user configuration files which do not
     * interfere with our ability to render fonts properly.
     */
    void load_user_fontconfig_files () {
        string [] exclude = {"78-Reject.conf"};
        try {
            string config_dir = get_config_dir();
            File directory = File.new_for_path(config_dir);
            FileEnumerator enumerator = directory.enumerate_children(FileAttribute.STANDARD_NAME, 0);
            GLib.FileInfo file_info;
            while ((file_info = enumerator.next_file ()) != null) {
                string filename = file_info.get_name();
                if (filename.has_suffix(".conf")) {
                    if (filename in exclude)
                        continue;
                    string filepath = Path.build_filename(config_dir, filename);
                    if (!load_config(filepath))
                        warning("Fontconfig : Failed to parse file : %s", filepath);
                }
            }
        } catch (Error e) {
            critical(e.message);
        }
        return;
    }

    bool load_user_font_sources (Gee.HashSet <string> dirs, Gee.HashSet <FontSource> sources) {
        if (!add_app_font_dir(Path.build_filename(Environment.get_user_data_dir(), "fonts")))
            return false;
        /* XXX : https://bugs.freedesktop.org/show_bug.cgi?id=64766 */
        foreach (var dir in dirs)
            if (!add_app_font_dir(dir))
                return false;
        foreach (var source in sources) {
            if (source.path in dirs)
                continue;
            add_app_font_dir(source.path);
        }
        return true;
    }

}
