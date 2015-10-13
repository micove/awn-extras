/*
 * Copyright (C) 2008 Rodney Cryderman <rcryderman@gmail.com>
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


#ifndef __TASKMANAGER_APPLET

#define __TASKMANAGER_APPLET

typedef struct
{
  GObject parent;
  DBusGConnection *connection;
} Taskmand;

typedef struct
{
  GObjectClass parent_class;
} TaskmandClass;

static void taskmand_init(Taskmand *server);
static void taskmand_class_init(TaskmandClass *class);

gboolean taskmand_launcher_register(Taskmand *obj, gchar *uid, GError **error);
gboolean taskmand_inform_task_ownership(Taskmand *obj, gchar *uid, gchar *pid, gchar *request, gchar ** response, GError **error);
gboolean taskmand_launcher_unregister(Taskmand *obj, gchar *uid, GError **error);
gboolean taskmand_launcher_position(Taskmand *obj, gchar *uid, GError **error);
gboolean taskmand_return_xid(Taskmand *obj, gchar *uid, gchar *id, GError **error);

#endif
