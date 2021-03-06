/*
 * Copyright (C) 2007, 2008, 2009 Rodney Cryderman <rcryderman@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
*/

#include "config.h"

#include "gnome-menu-builder.h"

#define GMENU_I_KNOW_THIS_IS_UNSTABLE
#include <gnome-menus-3.0/gmenu-tree.h>
#include <glib/gi18n.h>
#include <libdesktop-agnostic/fdo.h>
#include <gio/gio.h>
#include <stdarg.h>

#include <libawn/libawn.h>
#include "cairo-menu.h"
#include "cairo-menu-item.h"
#include "misc.h"
#include "cairo-menu-applet.h"

/* This sets the maximum number of volumes to show inline in Places.
   If there are more items, they are shown in a submenu.
   Maybe we should also apply this to bookmarks.
   TODO Read this number from config. */
#define MAX_ITEMS_OR_SUBMENU 7

GMenuTree *  main_menu_tree = NULL;
GMenuTree *  settings_menu_tree = NULL;    

GtkWidget *  menu_build (MenuInstance * instance);
static GtkWidget * submenu_build (MenuInstance * instance);

static GtkWidget *
get_image_from_gicon (GIcon * gicon)
{
  const gchar *const * icon_names =NULL;
  GtkWidget * image = NULL;
  if (G_IS_THEMED_ICON (gicon))
  {
    icon_names = g_themed_icon_get_names (G_THEMED_ICON(gicon));
  }
  if (icon_names)
  {
    const gchar *const *i;
    for (i=icon_names; *i; i++)
    {
      image = get_gtk_image (*i);
      if (image)
      {
        break;
      }
    }
  }
  return image;
}

static gboolean
add_special_item (GtkWidget * menu,
                  const gchar * name, 
                  const gchar * binary,
                  const gchar * args,
                  ...)
{
  GtkWidget * item;
  gchar *exec;
  GtkWidget * image;
  gchar * bin_path;
  va_list ap;
  gchar * icon_name;
  int i;

  va_start(ap, args);

  bin_path = g_find_program_in_path (binary);
  if (!bin_path)
  {
    return FALSE;
  }
  if (bin_path != binary)
  {
    g_free (bin_path);
  }
  item = cairo_menu_item_new_with_label (name);
  do
  {
    icon_name = va_arg(ap, gchar *);
    image = get_gtk_image (icon_name);
  } while (!image && icon_name);
  va_end(ap);

  if (image)
  {
    gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (item),image);
  }
  exec = g_strdup_printf("%s %s", binary ,args);
  g_signal_connect(G_OBJECT(item), "activate", G_CALLBACK(_exec), exec);
  g_object_weak_ref (G_OBJECT(item),(GWeakNotify) g_free,exec);
  gtk_menu_shell_append(GTK_MENU_SHELL(menu),item);
  return TRUE;
}

static gboolean
_fill_session_menu (GtkWidget * menu)
{
  gboolean have_gnome_session_manager = dbus_service_exists ("org.gnome.SessionManager");

  if (have_gnome_session_manager)
  {
    add_special_item (menu,_("Logout"),"gnome-session-save","--logout-dialog --gui","gnome-logout",NULL);
  }
  else if (dbus_service_exists ("org.xfce.SessionManager") )
  {
    add_special_item (menu,_("Logout"),"xfce4-session-logout","","gnome-logout",NULL);
  }
  else
  {
    /* hope that gnome-session-save exists; needed for GNOME 2.22, at least. */
    add_special_item (menu, _("Logout"), "gnome-session-save",
                      "--kill --gui", "gnome-logout",NULL);
  }
  if (dbus_service_exists ("org.gnome.ScreenSaver"))
  {
    if (!add_special_item (menu,_("Lock Screen"),"gnome-screensaver-command","--lock","gnome-lockscreen",NULL))
    {
      add_special_item (menu,_("Lock Screen"),"dbus-send","--session --dest=org.gnome.ScreenSaver --type=method_call --print-reply --reply-timeout=2000 /org/gnome/ScreenSaver org.gnome.ScreenSaver.Lock","gnome-lockscreen",NULL);
    }
  }
  else
  {
    add_special_item (menu,_("Lock Screen"),"xscreensaver-command","-lock","system-lock-screen",NULL);
  }
  if (dbus_service_exists ("org.freedesktop.PowerManagement"))
  {
    if (!add_special_item (menu,_("Suspend"),"gnome-power-cmd","suspend","gnome-session-suspend",NULL))
    {
      add_special_item (menu,_("Suspend"),"dbus-send","--session --dest=org.freedesktop.PowerManagement --type=method_call --print-reply --reply-timeout=2000 /org/freedesktop/PowerManagement org.freedesktop.PowerManagement.Suspend","gnome-session-suspend",NULL);
    }
    
    if (!add_special_item (menu,_("Hibernate"),"gnome-power-cmd","hibernate","gnome-session-hibernate",NULL))
    {
      add_special_item (menu,_("Hibernate"),"dbus-send","--session --dest=org.freedesktop.PowerManagement --type=method_call --print-reply --reply-timeout=2000 /org/freedesktop/PowerManagement org.freedesktop.PowerManagement.Hibernate","gnome-session-hibernate",NULL);
    }

  }
  else if (dbus_service_exists ("org.gnome.PowerManagement"))
  {
    if (!add_special_item (menu,_("Suspend"),"gnome-power-cmd","suspend","gnome-session-suspend",NULL))
    {

    }
      
    if (!add_special_item (menu,_("Hibernate"),"gnome-power-cmd","hibernate","gnome-session-hibernate",NULL))
    {

    }
  }
  
  if (have_gnome_session_manager)
  {
    add_special_item (menu,_("Shutdown"),"gnome-session-save","--shutdown-dialog --gui","gnome-shutdown","gnome-logout",NULL);  
  }
  gtk_widget_show_all (menu);
  return FALSE;
}

static GtkWidget *
get_session_menu(void)
{
  GtkWidget *menu = cairo_menu_new();
  /*so we don't stall checking the dbus services on applet startup*/
  g_idle_add ((GSourceFunc)_fill_session_menu,menu);
  return menu;
}
/*
 TODO:
  check for existence of the various bins.
  why are vfs network mounts not showing?
  The menu item order needs to be fixed.
 */
static GtkWidget * 
_get_places_menu (GtkWidget * menu)
{  
  static GVolumeMonitor* vol_monitor = NULL;
  static DesktopAgnosticVFSGtkBookmarks *bookmarks_parser = NULL;  
  static DesktopAgnosticVFSTrash* trash_handler = NULL;
  
  GtkWidget *item = NULL;
  GError *error = NULL;
  GtkWidget * image;
  gchar * exec;
  const gchar *desktop_dir = g_get_user_special_dir (G_USER_DIRECTORY_DESKTOP);
  const gchar *homedir = g_get_home_dir();
  guint trash_file_count;    

  gtk_container_foreach (GTK_CONTAINER (menu),(GtkCallback)_remove_menu_item,menu);

  add_special_item (menu,_("Computer"),"nautilus","computer:///","computer",NULL);
  gchar *home_quoted, *desktop_quoted;
  home_quoted = g_shell_quote (homedir);
  desktop_quoted = g_shell_quote (desktop_dir);
  add_special_item (menu,_("Home"),XDG_OPEN,home_quoted,"folder-home","stock_home",NULL);
  add_special_item (menu,_("Desktop"),XDG_OPEN,desktop_dir?desktop_quoted:home_quoted,"desktop",NULL);
  g_free (home_quoted);
  g_free (desktop_quoted);
  
  if (trash_handler)
    trash_file_count = desktop_agnostic_vfs_trash_get_file_count (trash_handler);

  if (trash_file_count == 0)
    add_special_item (menu,_("Trash"),"nautilus","trash:///","user-trash",NULL);
  else
    add_special_item (menu,_("Trash"),"nautilus","trash:///","stock_trash_full",NULL);

  add_special_item (menu,_("File System"),XDG_OPEN,"/","system",NULL);
    
  if (!vol_monitor)
  {
    /*this is structured like this because get_places() is
    invoked any time there is a change in places... only want perform
    these actions once.*/
    vol_monitor = g_volume_monitor_get();
    bookmarks_parser = desktop_agnostic_vfs_gtk_bookmarks_new (NULL, TRUE);
    trash_handler = desktop_agnostic_vfs_trash_get_default (&error);
    if (error)
    {
      g_critical ("Error with trash handler: %s", error->message);
      g_error_free (error);
    }
  }
  g_signal_handlers_disconnect_by_func (vol_monitor, G_CALLBACK(_get_places_menu), menu);
  g_signal_handlers_disconnect_by_func (vol_monitor, G_CALLBACK(_get_places_menu), menu);
  g_signal_handlers_disconnect_by_func (vol_monitor, G_CALLBACK(_get_places_menu), menu);
  g_signal_handlers_disconnect_by_func (vol_monitor, G_CALLBACK(_get_places_menu), menu);    
  g_signal_handlers_disconnect_by_func (vol_monitor, G_CALLBACK(_get_places_menu), menu);
  g_signal_handlers_disconnect_by_func (vol_monitor, G_CALLBACK(_get_places_menu), menu);
  g_signal_handlers_disconnect_by_func (vol_monitor, G_CALLBACK(_get_places_menu), menu);
  g_signal_handlers_disconnect_by_func (G_OBJECT (bookmarks_parser), G_CALLBACK (_get_places_menu), menu);
  g_signal_handlers_disconnect_by_func (trash_handler, G_CALLBACK(_get_places_menu), menu);
    
  g_signal_connect_swapped(vol_monitor, "volume-changed", G_CALLBACK(_get_places_menu), menu);
  g_signal_connect_swapped(vol_monitor, "drive-changed", G_CALLBACK(_get_places_menu), menu);
  g_signal_connect_swapped(vol_monitor, "drive-connected", G_CALLBACK(_get_places_menu), menu);
  g_signal_connect_swapped(vol_monitor, "drive-disconnected", G_CALLBACK(_get_places_menu), menu);    
  g_signal_connect_swapped(vol_monitor, "mount-changed", G_CALLBACK(_get_places_menu), menu);
  g_signal_connect_swapped(vol_monitor, "mount-added", G_CALLBACK(_get_places_menu), menu);
  g_signal_connect_swapped(vol_monitor, "mount-removed", G_CALLBACK(_get_places_menu), menu);
  g_signal_connect_swapped (G_OBJECT (bookmarks_parser), "changed",
                      G_CALLBACK (_get_places_menu), menu);
  g_signal_connect_swapped(trash_handler, "file-count-changed", G_CALLBACK(_get_places_menu), menu);

  /* Process mounts and volumes */
  GList *volumes = g_volume_monitor_get_volumes (vol_monitor);
  GList *mounts = g_volume_monitor_get_mounts (vol_monitor);
  GList * iter;
  GVolume * volume = NULL;

  for (iter = mounts; iter ; iter = g_list_next (iter))
  {
    GMount *mount = iter->data;

    /* Volumes (mounted or not) are added later, don't show twice */
    volume = g_mount_get_volume (mount);
    if (volume)
    {
      g_object_unref (volume);
      continue;
    }
    
#if GLIB_CHECK_VERSION(2,20,0)
    /* Shadowed mounts should not be displayed, see GIO reference manual */
    if (g_mount_is_shadowed (mount))
    {
      continue;
    }
#endif

    gchar * name = g_mount_get_name (mount);
    GIcon * gicon = g_mount_get_icon (mount);
    GFile * file = g_mount_get_root (mount);
    gchar * uri = g_file_get_uri (file);

    item = cairo_menu_item_new_with_label (name);    
#if GTK_CHECK_VERSION(2,14,0)
    image = gtk_image_new_from_gicon (gicon, GTK_ICON_SIZE_MENU);
#else
    image = get_image_from_gicon (gicon);
#endif
    gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (item),image);

    gtk_menu_shell_append (GTK_MENU_SHELL(menu),item);

    exec = g_strdup_printf("%s %s", XDG_OPEN, uri);
    g_signal_connect(G_OBJECT(item), "activate", G_CALLBACK(_exec), exec);  
    g_object_weak_ref (G_OBJECT(item), (GWeakNotify)g_free,exec);
    
    g_free (name);
    g_free (uri);
    g_object_unref (file);
    g_object_unref (gicon);
  }

  g_list_foreach (mounts,(GFunc)g_object_unref,NULL);
  g_list_free (mounts);
 
  if (volumes)
  {
    item = gtk_separator_menu_item_new ();
    gtk_menu_shell_append(GTK_MENU_SHELL(menu),item);
  }

  /* Get Volumes */

  GtkWidget *volumes_menu;
  
  volumes_menu = ((g_list_length (volumes) <= MAX_ITEMS_OR_SUBMENU)) ?
                 menu :
                 cairo_menu_new();

  for (iter = volumes; iter ; iter = g_list_next (iter))
  {
    GIcon * gicon = g_volume_get_icon (iter->data);
    gchar * name = g_volume_get_name (iter->data);
    
    item = cairo_menu_item_new_with_label (name);
#if GTK_CHECK_VERSION(2,14,0)
    image = gtk_image_new_from_gicon (gicon, GTK_ICON_SIZE_MENU);
#else
    image = get_image_from_gicon (gicon);
#endif
    gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (item),image);

    gtk_menu_shell_append(GTK_MENU_SHELL(volumes_menu),item);

    /* the callback opens unmounted as well as mounted volumes */
    g_signal_connect_data (G_OBJECT(item), "activate",
                           G_CALLBACK(_mount), g_object_ref (iter->data),
                           (GClosureNotify) g_object_unref, 0);

    g_free (name);
    g_object_unref (gicon);
  }
  
  if (g_list_length (volumes) > MAX_ITEMS_OR_SUBMENU)
  {
    item = cairo_menu_item_new_with_label (_("Removable Media"));
    image = get_gtk_image ("gnome-dev-removable");
    gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (item),image);

    gtk_menu_item_set_submenu (GTK_MENU_ITEM(item),volumes_menu);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu),item);
  }

  g_list_foreach (volumes,(GFunc)g_object_unref,NULL);
  g_list_free (volumes);

  add_special_item (menu,_("Network"),"nautilus","network:/","network",NULL);
  add_special_item (menu,_("Connect to Server"),"nautilus-connect-server","","stock_connect",NULL);
  item = gtk_separator_menu_item_new ();
  gtk_menu_shell_append(GTK_MENU_SHELL(menu),item);

    
  /* Bookmarks */
  GSList *bookmarks;
  GSList *node;

  bookmarks = desktop_agnostic_vfs_gtk_bookmarks_get_bookmarks (bookmarks_parser);
  for (node = bookmarks; node != NULL; node = node->next)
  {
    DesktopAgnosticVFSBookmark *bookmark;
    DesktopAgnosticVFSFile *b_file;
    const gchar *b_alias;
    gchar *b_path;
    gchar *b_uri;
    gchar *shell_quoted = NULL;
    item = NULL;
    
    bookmark = (DesktopAgnosticVFSBookmark*)node->data;
    b_file = desktop_agnostic_vfs_bookmark_get_file (bookmark);
    b_alias = desktop_agnostic_vfs_bookmark_get_alias (bookmark);
    b_path = desktop_agnostic_vfs_file_get_path (b_file);
    b_uri = desktop_agnostic_vfs_file_get_uri (b_file);

    if (b_path && !desktop_agnostic_vfs_file_exists(b_file))
    {
      /* leave item as NULL */
    }
    else if (b_path)
    {
      shell_quoted = g_shell_quote (b_path);
      exec = g_strdup_printf("%s %s", XDG_OPEN,shell_quoted);
      g_free (shell_quoted);
      if (b_alias)
      {
        item = cairo_menu_item_new_with_label (b_alias);
      }
      else
      {
        gchar * base = g_path_get_basename (b_path);
        item = cairo_menu_item_new_with_label (base);        
        g_free (base);
      }
      g_signal_connect(G_OBJECT(item), "activate", G_CALLBACK(_exec), exec);              
      gtk_menu_shell_append(GTK_MENU_SHELL(menu),item);
    }
    else if ( strncmp(b_uri, "http", 4)==0 )
    {
      shell_quoted = g_shell_quote (b_uri);
      exec = g_strdup_printf("%s %s",XDG_OPEN,shell_quoted);
      g_free (shell_quoted);
      if (b_alias)
      {
        item = cairo_menu_item_new_with_label (b_alias);
      }
      else
      {
        gchar * base = g_path_get_basename (b_uri);
        item = cairo_menu_item_new_with_label (b_uri);
        g_free (base);
      }
      g_signal_connect(G_OBJECT(item), "activate", G_CALLBACK(_exec), exec);              
      gtk_menu_shell_append(GTK_MENU_SHELL(menu),item);
    }
    /*
     non-http(s) uris.  open with nautils.  obviously we should be smarter about
     this
     */
    else if (b_uri)
    {
      shell_quoted = g_shell_quote (b_uri);
      exec = g_strdup_printf("%s %s", "nautilus" ,shell_quoted);
      g_free (shell_quoted);
      if (b_alias)
      {
        item = cairo_menu_item_new_with_label (b_alias);
      }
      else
      {
        gchar * base = g_path_get_basename (b_uri);
        item = cairo_menu_item_new_with_label (base);
        g_free (base);
      }
      if (item)
      {
        g_signal_connect(G_OBJECT(item), "activate", G_CALLBACK(_exec), exec);      
        gtk_menu_shell_append(GTK_MENU_SHELL(menu),item);
      }
    }

    if (item)
    {
      /* Set icons for known paths and remote destinations */
      
      if (g_strcmp0 (b_uri, "computer:///") == 0)
      {
        image = get_gtk_image ("computer");
      }
      else if (g_strcmp0 (b_path, homedir) == 0)
      {
        image = get_gtk_image ("folder-home");
      }
      else if (g_strcmp0 (b_path, desktop_dir) == 0)
      {
        image = get_gtk_image ("desktop");
      }
      else if (g_strcmp0 (b_path, g_get_user_special_dir (G_USER_DIRECTORY_DOCUMENTS)) == 0)
      {
        image = get_gtk_image ("folder-documents");
      }
      else if (g_strcmp0 (b_path, g_get_user_special_dir (G_USER_DIRECTORY_DOWNLOAD)) == 0)
      {
        image = get_gtk_image ("folder-download");
      }
      else if (g_strcmp0 (b_path, g_get_user_special_dir (G_USER_DIRECTORY_MUSIC)) == 0)
      {
        image = get_gtk_image ("folder-music");
      }
      else if (g_strcmp0 (b_path, g_get_user_special_dir (G_USER_DIRECTORY_PICTURES)) == 0)
      {
        image = get_gtk_image ("folder-pictures");
      }
      else if (g_strcmp0 (b_path, g_get_user_special_dir (G_USER_DIRECTORY_PUBLIC_SHARE)) == 0)
      {
        image = get_gtk_image ("folder-publicshare");
      }
      else if (g_strcmp0 (b_path, g_get_user_special_dir (G_USER_DIRECTORY_TEMPLATES)) == 0)
      {
        image = get_gtk_image ("folder-templates");
      }
      else if (g_strcmp0 (b_path, g_get_user_special_dir (G_USER_DIRECTORY_VIDEOS)) == 0)
      {
        image = get_gtk_image ("folder-videos");
      }
      else if (!b_path)
      {
        image = get_gtk_image ("folder-remote");
      }
      else
      {
        image = get_gtk_image ("stock_folder");
      }

      /* For icon themes that don't feature icons for special directories */
      if (!image)
      {
        image = get_gtk_image ("stock_folder");
      }

      gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (item),image);
    }
    g_free (b_path);
    g_free (b_uri);
  }
  gtk_widget_show_all (menu);
  return menu;
}

GtkWidget * 
get_places_menu (void)
{
  GtkWidget *menu = cairo_menu_new();
  _get_places_menu (menu);
  return menu;
}

static GtkWidget *
fill_er_up(MenuInstance * instance,GMenuTreeDirectory *directory, GtkWidget * menu)
{
  static gint sanity_depth_count = 0;
  GMenuTreeIter *iter =   gmenu_tree_directory_iter(directory);
  GtkWidget * menu_item = NULL;
  GtkWidget * sub_menu = NULL;
  const gchar * txt;
  GIcon *icon;
  gchar * desktop_file;
  DesktopAgnosticFDODesktopEntry *entry;
  GtkWidget * image;
  gboolean detached_sub = FALSE;
  gchar * uri;

  sanity_depth_count++;
  if (sanity_depth_count>6)
  {
    sanity_depth_count--;
    g_warning ("%s: Exceeded max menu depth of 6 at %s",__func__,gmenu_tree_directory_get_name((GMenuTreeDirectory*)directory));
    return cairo_menu_new ();
  }
  if (!menu)
  {
    menu = cairo_menu_new ();
  }
  
  for (;;)
  {

    switch (gmenu_tree_iter_next(iter))
    {

      case GMENU_TREE_ITEM_INVALID:
	    goto done;
      case GMENU_TREE_ITEM_ENTRY:
	{
        GMenuTreeEntry *mentry = gmenu_tree_iter_get_entry(iter);
	GAppInfo *app_info = (GAppInfo *)gmenu_tree_entry_get_app_info(mentry);
        if (!gmenu_tree_entry_get_is_excluded (mentry)) {
	txt = g_app_info_get_display_name(app_info);
	icon = g_app_info_get_icon(app_info);
        desktop_file = g_strdup (gmenu_tree_entry_get_desktop_file_path (mentry));
        uri = g_strdup_printf("file://%s\n",desktop_file);
	  image = get_image_from_gicon(icon);
          menu_item = cairo_menu_item_new_with_label (txt?txt:"unknown");
          if (image)
          {
            gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (menu_item),image);
          }
          gtk_menu_shell_append(GTK_MENU_SHELL(menu),menu_item);
          gtk_widget_show_all (menu_item);
          g_signal_connect(G_OBJECT(menu_item), "activate", G_CALLBACK(_launch), desktop_file);
//          g_signal_connect(G_OBJECT(menu_item), "button-release-event", G_CALLBACK(_launch), desktop_file);
          cairo_menu_item_set_source (AWN_CAIRO_MENU_ITEM(menu_item),uri);
          g_free (uri);          
        }
	gmenu_tree_item_unref(mentry);
	}
        break;

      case GMENU_TREE_ITEM_DIRECTORY:
	{
	GMenuTreeDirectory *directory = gmenu_tree_iter_get_directory(iter);
        if (!gmenu_tree_directory_get_is_nodisplay ( directory))
        {
          CallbackContainer * c;
          gchar * drop_data;
          c = g_malloc0 (sizeof(CallbackContainer));          
          c->icon_name = g_icon_to_string(gmenu_tree_directory_get_icon (directory));
          image = get_gtk_image (c->icon_name);
          if (!image)
          {
            image = get_gtk_image ("stock_folder");
          }
          sub_menu = GTK_WIDGET(fill_er_up( instance,directory,NULL));
	  txt = gmenu_tree_directory_get_name(directory);
	  menu_item = cairo_menu_item_new_with_label (txt?txt:"unknown");
          gtk_menu_item_set_submenu (GTK_MENU_ITEM(menu_item),sub_menu);
          if (image)
          {
            gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (menu_item),image);
          }        
          gtk_menu_shell_append(GTK_MENU_SHELL(menu),menu_item);
          c->file_path = g_strdup(gmenu_tree_directory_get_desktop_file_path (directory));
          c->display_name = g_strdup (gmenu_tree_directory_get_name (directory));
          c->instance = instance;          
          /*
           TODO: possibly change data
           */
          drop_data = g_strdup_printf("cairo_menu_item_dir:///@@@%s@@@%s@@@%s\n",c->file_path,c->display_name,c->icon_name);
          cairo_menu_item_set_source (AWN_CAIRO_MENU_ITEM(menu_item),drop_data);
          g_free (drop_data);
          g_signal_connect (menu_item, "button-press-event",G_CALLBACK(_button_press_dir),c);
          g_object_weak_ref (G_OBJECT(menu_item),(GWeakNotify)_free_callback_container,c);
        }
	gmenu_tree_item_unref(directory);
	}
        break;
      case GMENU_TREE_ITEM_HEADER:
//    printf("GMENU_TREE_ITEM_HEADER\n");
        break;

      case GMENU_TREE_ITEM_SEPARATOR:
        menu_item = gtk_separator_menu_item_new ();
        gtk_menu_shell_append(GTK_MENU_SHELL(menu),menu_item);          
        break;

      case GMENU_TREE_ITEM_ALIAS:
//    printf("GMENU_TREE_ITEM_ALIAS\n");
        /*      {
             GMenuTreeItem *aliased_item;

             aliased_item = gmenu_tree_alias_get_item (GMENU_TREE_ALIAS (item));
             if (gmenu_tree_item_get_type (aliased_item) == GMENU_TREE_ITEM_ENTRY)
                print_entry (GMENU_TREE_ENTRY (aliased_item), path);
              }*/
        break;

      default:
        g_assert_not_reached();
        break;
    }

  }
done:
  gmenu_tree_iter_unref(iter);
  if (menu)
  {
    gtk_widget_show_all (menu);
  }
  sanity_depth_count--;
  return menu;
}

static void
_run_dialog (GtkMenuItem * item, MenuInstance *instance)
{
  const gchar * cmd;
  gchar * file_path;
  cmd = instance->run_cmd_fn (AWN_APPLET(instance->applet));
  if (cmd)
  {
    g_spawn_command_line_async (cmd,NULL);
  }
}

static void
_search_dialog (GtkMenuItem * item, MenuInstance * instance)
{
  const gchar * cmd;
  cmd = instance->search_cmd_fn (AWN_APPLET(instance->applet));
  if (cmd)
  {
    g_spawn_command_line_async (cmd,NULL);
  }
}

static gboolean
_delayed_update (MenuInstance * instance)
{
  instance->source_id=0;  
  instance->menu = menu_build (instance);  
  return FALSE;
}

static void 
_menu_modified_cb(GMenuTree *tree,MenuInstance * instance)
{

  /*
 keeps a runaway stream of callbacks from occurring in certain circumstances
 */
  if (!instance->source_id)
  {
    instance->source_id = g_timeout_add_seconds (5,(GSourceFunc)_delayed_update,instance);
  }
}

static GMenuTreeDirectory *
find_menu_dir (MenuInstance * instance, GMenuTreeDirectory * root)
{
  g_return_val_if_fail (root,NULL);
  GMenuTreeIter *iter = NULL;
  GMenuTreeDirectory * result = NULL;
  const gchar * txt = NULL;

  txt = gmenu_tree_directory_get_desktop_file_path (root);
  if (g_strcmp0(txt,instance->submenu_name)==0 )
  {
    gmenu_tree_item_ref (root);
    return root;
  }

  iter = gmenu_tree_directory_iter(root);  
  for (;;)
  {

    switch (gmenu_tree_iter_next(iter))
    {
      case GMENU_TREE_ITEM_DIRECTORY:
	{
	GMenuTreeDirectory *directory = gmenu_tree_iter_get_directory(iter);
        if (!gmenu_tree_directory_get_is_nodisplay (directory))
        {
          txt = gmenu_tree_directory_get_desktop_file_path (directory);
          if (g_strcmp0(txt,instance->submenu_name)==0 )
          {
            result = directory;
            break;            
          }
          else if (!result)  /*we're continuing looping if result to unref the remaining items*/
          {
            result = find_menu_dir (instance, directory);
          }
        }
        }
        /*deliberately falling through*/
      case GMENU_TREE_ITEM_ENTRY:
      case GMENU_TREE_ITEM_HEADER:
      case GMENU_TREE_ITEM_SEPARATOR:
      case GMENU_TREE_ITEM_ALIAS:
        break;
      default:
        g_assert_not_reached();
        break;
    }
  }
done:
  gmenu_tree_iter_unref(iter);
  return result;
}

static void
clear_menu (MenuInstance * instance)
{
  if (instance->menu)
  {
    GList * children = gtk_container_get_children (GTK_CONTAINER(instance->menu));
    GList * iter;
    for (iter = children;iter;)
    {
      if ( (iter->data !=instance->places) && (iter->data!=instance->recent)&& (iter->data!=instance->session))
      {
        gtk_container_remove (GTK_CONTAINER (instance->menu),iter->data);
        /*TODO  check if this is necessary*/
        g_list_free (children);        
        children = iter = gtk_container_get_children (GTK_CONTAINER(instance->menu));
        continue;
      }
      iter=g_list_next (iter);     
    }
    if (children)
    {
      g_list_free (children);
    }
  }
}

static gboolean
_submenu_delayed_update (MenuInstance * instance)
{
  instance->source_id=0;  
  instance->menu = submenu_build (instance);  
  return FALSE;
}


static void 
_submenu_modified_cb(GMenuTree *tree,MenuInstance * instance)
{

  /*
 keeps a runaway stream of callbacks from occurring in certain circumstances
 */
  if (!instance->source_id)
  {
    instance->source_id = g_timeout_add_seconds (5,(GSourceFunc)_submenu_delayed_update,instance);
  }
}

static void 
_remove_main_submenu_cb(MenuInstance * instance,GObject *where_the_object_was)
{
  g_debug ("%s",__func__);
  GMenuTreeDirectory *main_root;
  g_signal_handlers_disconnect_by_func(main_menu_tree,G_CALLBACK(_submenu_modified_cb), instance);
}

static void 
_remove_settings_submenu_cb(MenuInstance * instance,GObject *where_the_object_was)
{
  g_debug ("%s",__func__);  
  GMenuTreeDirectory *main_root;
  g_signal_handlers_disconnect_by_func(settings_menu_tree,G_CALLBACK(_submenu_modified_cb), instance);
}

static GtkWidget *
submenu_build (MenuInstance * instance)
{
  GMenuTreeDirectory *main_root;
  GMenuTreeDirectory *settings_root;
  GtkWidget * menu = NULL;
  /*
   if the menu is set then clear any menu items (except for places or recent)
   */
  clear_menu (instance);
  if (!main_menu_tree)
  {
    GError *err;
    main_menu_tree = gmenu_tree_new("gnome-applications.menu", GMENU_TREE_FLAGS_NONE);
    if (!gmenu_tree_load_sync (main_menu_tree, &err)) {
	    g_warning("gmenu_tree_load_sync err %s", err->message);
	    g_error_free(err);
    }
  }
  if (!settings_menu_tree)
  {
    GError *err;
    settings_menu_tree = gmenu_tree_new("gnomecc.menu", GMENU_TREE_FLAGS_NONE);
    if (!gmenu_tree_load_sync (settings_menu_tree, &err)) {
	    g_warning("gmenu_tree_load_sync err %s", err->message);
	    g_error_free(err);
    }
  }
  g_assert (main_menu_tree);
  /*
   get_places_menu() and get_recent_menu() are 
   responsible for managing updates in place.  Session should only need
   to be created once or may eventually need to follow the previously mentioned
   behaviour.   Regardless... they should only need to be created here from scratch,
   this fn should _not_ be invoked in a refresh of those menus.

   We don't want to rebuild the whole menu tree everytime a vfs change occurs 
   or a document is accessed
   */
  if (g_strcmp0(instance->submenu_name,":::PLACES")==0)
  {
    g_assert (!instance->menu);
    menu = get_places_menu ();
  }
  else if (g_strcmp0(instance->submenu_name,":::RECENT")==0)
  {
    g_assert (!instance->menu);    
    menu = get_recent_menu (NULL);
  }
  else if (g_strcmp0(instance->submenu_name,":::SESSION")==0)
  {
    g_assert (!instance->menu);    
    menu = get_session_menu ();
  }
  else
  {
    GMenuTreeDirectory * menu_dir = NULL;    
    
    main_root = gmenu_tree_get_root_directory(main_menu_tree);
    //g_assert (gmenu_tree_item_get_type( (GMenuTreeItem*)main_root) == GMENU_TREE_ITEM_DIRECTORY);
    g_assert (main_root);
    settings_root = gmenu_tree_get_root_directory(settings_menu_tree);
    if ( menu_dir = find_menu_dir (instance,main_root) )
    {
      /* if instance->menu then we're refreshing in a monitor callback*/
      g_signal_handlers_disconnect_by_func(main_menu_tree,G_CALLBACK(_submenu_modified_cb), instance);
      g_signal_connect(main_menu_tree,"changed",G_CALLBACK(_submenu_modified_cb), instance);
      menu = fill_er_up(instance,menu_dir,instance->menu);
      g_object_weak_ref (G_OBJECT(menu), (GWeakNotify)_remove_main_submenu_cb,instance);
    }
    else if ( settings_root && (menu_dir = find_menu_dir (instance,settings_root)) )
    {
      g_signal_handlers_disconnect_by_func(main_menu_tree,G_CALLBACK(_submenu_modified_cb), instance);
      g_signal_connect(main_menu_tree,"changed",G_CALLBACK(_submenu_modified_cb), instance);
      menu = fill_er_up(instance,menu_dir,instance->menu);
      g_object_weak_ref (G_OBJECT(menu), (GWeakNotify)_remove_settings_submenu_cb,instance);
    }
    if (menu_dir)
    {      
      gmenu_tree_item_unref(menu_dir);
    }
    gmenu_tree_item_unref(main_root);
    if (settings_root)
    {
      gmenu_tree_item_unref(settings_root);
    }
  }
  return instance->menu = menu;
}

/*
 TODO: add network, and trash

 */
GtkWidget * 
menu_build (MenuInstance * instance)
{
  GMenuTreeDirectory *root;
  GtkWidget * image = NULL;
  GtkWidget   *menu_item;
  GtkWidget * sub_menu;
  const gchar * txt;
  CallbackContainer * c;
  gchar * drop_data;

  if (instance->submenu_name)
  {
    return instance->menu = submenu_build (instance);
  }
  
  clear_menu (instance);    
  if (!main_menu_tree)
  {
	  GError *err;
    main_menu_tree = gmenu_tree_new("gnome-applications.menu", GMENU_TREE_FLAGS_NONE);
    if (!gmenu_tree_load_sync (main_menu_tree, &err)) {
	    g_warning("gmenu_tree_load_sync err %s", err->message);
	    g_error_free(err);
    }
  }
  if (!settings_menu_tree)
  {
     GError *err;
    settings_menu_tree = gmenu_tree_new("gnomecc.menu", GMENU_TREE_FLAGS_NONE);
    if (!gmenu_tree_load_sync (settings_menu_tree, &err)) {
	    g_warning("gmenu_tree_load_sync err %s", err->message);
	    g_error_free(err);
    }
  }

  if (main_menu_tree)
  {
    root = gmenu_tree_get_root_directory(main_menu_tree);
    if (root)
    {
      g_assert (!instance->submenu_name);
      g_signal_handlers_disconnect_by_func(main_menu_tree,G_CALLBACK(_menu_modified_cb), instance);
      g_signal_connect(main_menu_tree,"changed",G_CALLBACK(_menu_modified_cb), instance);
      instance->menu = fill_er_up(instance,root,instance->menu);
      gmenu_tree_item_unref(root);
    }
  }
  if  (instance->menu)
  {  
      menu_item = gtk_separator_menu_item_new ();
      gtk_menu_shell_append(GTK_MENU_SHELL(instance->menu),menu_item);  
  }
  if (settings_menu_tree)
  {
    root = gmenu_tree_get_root_directory(settings_menu_tree);
      g_signal_handlers_disconnect_by_func(settings_menu_tree,G_CALLBACK(_menu_modified_cb), instance);
      g_signal_connect(settings_menu_tree,"changed",G_CALLBACK(_menu_modified_cb), instance);
    if (!instance->menu)
    {
      g_debug ("%s:  No applications menu????",__func__);
      instance->menu = fill_er_up(instance,root,instance->menu);
    }
    else
    {
      sub_menu = fill_er_up (instance, root,instance->menu);
#if 0      
      sub_menu = fill_er_up(instance,root,NULL);
      c = g_malloc0 (sizeof(CallbackContainer));        
      c->icon_name = g_strdup(gmenu_tree_directory_get_icon (root));
      image = get_gtk_image (c->icon_name);
      txt = gmenu_tree_entry_get_name((GMenuTreeEntry*)root);        
      menu_item = cairo_menu_item_new_with_label (txt?txt:"unknown");        
      gtk_menu_item_set_submenu (GTK_MENU_ITEM(menu_item),sub_menu);
      if (image)
      {
        gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (menu_item),image);
      }        
      gtk_menu_shell_append(GTK_MENU_SHELL(instance->menu),menu_item);
      c->file_path = g_strdup(gmenu_tree_directory_get_desktop_file_path (root));
      c->display_name = g_strdup ("Settings");
      drop_data = g_strdup_printf("cairo_menu_item_dir:///@@@%s@@@%s@@@%s\n",c->file_path,c->display_name,c->icon_name);
      cairo_menu_item_set_source (AWN_CAIRO_MENU_ITEM(menu_item),drop_data);
      g_free (drop_data);
      c->instance = instance;
      g_signal_connect (menu_item, "button-press-event",G_CALLBACK(_button_press_dir),c);
      g_object_weak_ref (G_OBJECT(menu_item),(GWeakNotify)_free_callback_container,c);
#endif
    }
    gmenu_tree_item_unref(root);    
  }
    
    /*TODO Check to make sure it is needed. Should not be displayed if 
      all flags are of the NO persuasion.*/
  if  (instance->menu)
  {
     menu_item = gtk_separator_menu_item_new ();
     gtk_menu_shell_append(GTK_MENU_SHELL(instance->menu),menu_item);  
  }
  
  if (! (instance->flags & MENU_BUILD_NO_PLACES) )
  {
    if (instance->places)
    {
      GList * children = gtk_container_get_children (GTK_CONTAINER(instance->menu));
      menu_item =instance->places;
      gtk_menu_reorder_child (GTK_MENU(instance->menu),menu_item,g_list_length (children));
      g_list_free (children);
    }
    else
    {
      sub_menu = get_places_menu ();
      gchar * icon_name;
      instance->places = menu_item = cairo_menu_item_new_with_label (_("Places"));
      image = get_gtk_image (icon_name = "places");
      if (!image)
      {
        image = get_gtk_image(icon_name = "stock_folder");
      }
      if (image)
      {
        gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (menu_item),image);
      }
      gtk_menu_item_set_submenu (GTK_MENU_ITEM(menu_item),sub_menu);            
      gtk_menu_shell_append(GTK_MENU_SHELL(instance->menu),menu_item);
      c = g_malloc0 (sizeof(CallbackContainer));
      c->file_path = g_strdup(":::PLACES");
      c->display_name = g_strdup (_("Places"));
      c->icon_name = g_strdup(icon_name);
      drop_data = g_strdup_printf("cairo_menu_item_dir:///@@@%s@@@%s@@@%s\n",c->file_path,c->display_name,c->icon_name);
      cairo_menu_item_set_source (AWN_CAIRO_MENU_ITEM(menu_item),drop_data);
      g_free (drop_data);
      c->instance = instance;
      g_signal_connect (menu_item, "button-press-event",G_CALLBACK(_button_press_dir),c);
      g_object_weak_ref (G_OBJECT(menu_item),(GWeakNotify)_free_callback_container,c);
    }
  }
  
  if (! (instance->flags & MENU_BUILD_NO_RECENT))
  {
    if (instance->recent)
    {
      GList * children = gtk_container_get_children (GTK_CONTAINER(instance->menu));
      menu_item =instance->recent;
      gtk_menu_reorder_child (GTK_MENU(instance->menu),menu_item,g_list_length (children));
      g_list_free (children);        
    }
    else
    {
      gchar * icon_name;
      instance->recent = menu_item = cairo_menu_item_new_with_label (_("Recent Documents"));
      sub_menu = get_recent_menu (menu_item);        
      image = get_gtk_image (icon_name = "document-open-recent");
      if (!image)
      {
        image = get_gtk_image(icon_name = "stock_folder");
      }
      if (image)
      {
        gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (menu_item),image);
      }
      gtk_menu_item_set_submenu (GTK_MENU_ITEM(menu_item),sub_menu);
      gtk_menu_shell_append(GTK_MENU_SHELL(instance->menu),menu_item);
      c = g_malloc0 (sizeof(CallbackContainer));
      c->file_path = g_strdup(":::RECENT");
      c->display_name = g_strdup (_("Recent Documents"));
      c->icon_name = g_strdup(icon_name);
      drop_data = g_strdup_printf("cairo_menu_item_dir:///@@@%s@@@%s@@@%s\n",c->file_path,c->display_name,icon_name);
      cairo_menu_item_set_source (AWN_CAIRO_MENU_ITEM(menu_item),drop_data);
      g_free (drop_data);
      c->instance = instance;
      g_signal_connect (menu_item, "button-press-event",G_CALLBACK(_button_press_dir),c);
      g_object_weak_ref (G_OBJECT(menu_item),(GWeakNotify)_free_callback_container,c);
    }
  }

  /*TODO Check to make sure it is needed. avoid double separators*/
  if  (instance->menu &&  (!(instance->flags & MENU_BUILD_NO_RECENT) || !(instance->flags & MENU_BUILD_NO_PLACES))&&
     (!instance->check_menu_hidden_fn (instance->applet,":::RECENT") || !instance->check_menu_hidden_fn (instance->applet,":::PLACES")) )
  {
    menu_item = gtk_separator_menu_item_new ();
    gtk_menu_shell_append(GTK_MENU_SHELL(instance->menu),menu_item);  
  }

  if (! (instance->flags & MENU_BUILD_NO_SESSION))
  {
    if (instance->session)
    {
      GList * children = gtk_container_get_children (GTK_CONTAINER(instance->menu));
      menu_item =instance->session;
      gtk_menu_reorder_child (GTK_MENU(instance->menu),menu_item,g_list_length (children));
      g_list_free (children); 
    }
    else
    {    
      sub_menu = get_session_menu ();
      instance->session = menu_item = cairo_menu_item_new_with_label (_("Session"));
      image = get_gtk_image ("session-properties");
      if (image)
      {
        gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (menu_item),image);
      }        
      gtk_menu_item_set_submenu (GTK_MENU_ITEM(menu_item),sub_menu);
      gtk_menu_shell_append(GTK_MENU_SHELL(instance->menu),menu_item);

      c = g_malloc0 (sizeof(CallbackContainer));
      c->file_path = g_strdup(":::SESSION");
      c->display_name = g_strdup (_("Session"));
      c->icon_name = g_strdup("session-properties");
      drop_data = g_strdup_printf("cairo_menu_item_dir:///@@@%s@@@%s@@@%s\n",c->file_path,c->display_name,"session-properties");
      cairo_menu_item_set_source (AWN_CAIRO_MENU_ITEM(menu_item),drop_data);
      g_free (drop_data);
      c->instance = instance;
      g_signal_connect (menu_item, "button-press-event",G_CALLBACK(_button_press_dir),c);
      g_object_weak_ref (G_OBJECT(menu_item),(GWeakNotify)_free_callback_container,c);
    }
  }
  
  if (! (instance->flags & MENU_BUILD_NO_SEARCH))
  {  
    if ( !instance->submenu_name)
    {    
      /*generates a compiler warning due to the ellipse*/
      menu_item = cairo_menu_item_new_with_label (_("search\342\200\246"));
      /* add proper ellipse*/
      image = get_gtk_image ("stock_search");
      if (image)
      {
        gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (menu_item),image);
      }        
      gtk_menu_shell_append(GTK_MENU_SHELL(instance->menu),menu_item);
      g_signal_connect (menu_item,"activate",G_CALLBACK(_search_dialog),instance);
    }
  }
  
  if (! (instance->flags & MENU_BUILD_NO_RUN))
  {
    if ( !instance->submenu_name)
    {    
      /*generates a compiler warning due to the ellipse*/    
      menu_item = cairo_menu_item_new_with_label (_("Launch\342\200\246"));
      /* add proper ellipse*/
      image = get_gtk_image ("gnome-run");
      if (image)
      {
        gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (menu_item),image);
      }        
      gtk_menu_shell_append(GTK_MENU_SHELL(instance->menu),menu_item);
      g_signal_connect (menu_item,"activate",G_CALLBACK(_run_dialog),instance);
    }
  }

  gtk_widget_show_all (instance->menu);

  if ( !instance->check_menu_hidden_fn || instance->check_menu_hidden_fn (instance->applet,":::RECENT"))
  {
    if (instance->recent)
    {
      gtk_widget_hide (instance->recent);
    }
  }
  if ( !instance->check_menu_hidden_fn || instance->check_menu_hidden_fn (instance->applet,":::PLACES"))
  {    
    if (instance->places)
    {
      gtk_widget_hide (instance->places);
    }  
  }    
  if ( !instance->check_menu_hidden_fn || instance->check_menu_hidden_fn (instance->applet,":::SESSION"))
  {    
    if (instance->session)
    {
      gtk_widget_hide (instance->session);
    }
  }
  instance->done_once = TRUE;
  return instance->menu;
}
