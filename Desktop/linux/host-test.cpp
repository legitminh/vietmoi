#include <gtk/gtk.h>
#include <fstream>
#include <string>
static std::string output;
static void changed(GtkEditable *editable, gpointer) { std::ofstream(output) << gtk_entry_get_text(GTK_ENTRY(editable)); }
int main(int argc, char **argv) {
    gtk_init(&argc, &argv); output = argc > 1 ? argv[1] : "/tmp/sieuviet-host.txt";
    auto *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "Sieuviet host test"); gtk_window_set_default_size(GTK_WINDOW(window), 700, 220);
    auto *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12); gtk_container_add(GTK_CONTAINER(window), box);
    auto *entry = gtk_entry_new(); gtk_widget_set_name(entry, "first");
    gtk_box_pack_start(GTK_BOX(box), entry, TRUE, TRUE, 0);
    auto *second = gtk_entry_new();
    gtk_box_pack_start(GTK_BOX(box), second, TRUE, TRUE, 0);
    g_signal_connect(second, "changed", G_CALLBACK(+[](GtkEditable *editable, gpointer) {
        std::ofstream(output + ".second") << gtk_entry_get_text(GTK_ENTRY(editable));
    }), nullptr);
    g_signal_connect(entry, "changed", G_CALLBACK(changed), nullptr);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), nullptr);
    gtk_widget_show_all(window); gtk_widget_grab_focus(entry); gtk_main(); return 0;
}
