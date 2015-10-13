/*
 * Copyright (c) 2007   Rodney (moonbeam) Cryderman <rcryderman@gmail.com>
 *
 * urlencdoe and urldecode Copyright (C) 2001-2002 Open Source Telecom Corporation.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */
 
 
#ifndef _AWN_EXTRS_UTIL
#define _AWN_EXTRS_UTIL

#include <libawn/awn-cairo-utils.h>
#include <libawn/awn-applet.h>
#include <libawn/awn-applet-simple.h>
#include <gtk/gtk.h>
#include <string.h>
#include <gdk/gdk.h>
#include <glib.h>


char* urlencode(const char *source, char *dest, unsigned max);
char *urldecode(char *source, char *dest);

/*
surface_2_pixbuf
	-copies a cairo image surface to an allocated pixbuf of the same dimensions.
	-the heights and width must match.  Both must be ARGB.
*/
GdkPixbuf * surface_2_pixbuf( GdkPixbuf * pixbuf, cairo_surface_t * surface);
GdkPixbuf * get_pixbuf_from_surface(cairo_surface_t * surface);

/* 
awncolor_to_string
	Given an AwnColor argument returns an allocated string in the form of RRGGBBAA
*/
gchar * awncolor_to_string(AwnColor * colour);
AwnColor gdkcolor_to_awncolor_with_alpha( GdkColor * gdk_color,double alpha);
AwnColor gdkcolor_to_awncolor( GdkColor * gdk_colour);

/*
void notify_message
	Sends a notificication to a notification daemon.
	summary	-	message summary.
	body	-	body of message
	icon	-	full path to icon to display.  NULL indicates no icon.
	timeout	-	notificiation window timeout in ms.  0 indicates default should be used.
	returns	TRUE on success, FALSE on failure	
*/
gboolean notify_message(gchar * summary, gchar * body,gchar * icon_str,glong timeout);
/*
void notify_message_async
	Sends a notificication to a notification daemon in an asyncronous manner
	summary	-	message summary.
	body	-	body of message
	icon	-	full path to icon to display.  NULL indicates no icon.
	timeout	-	notificiation window timeout in ms.  0 indicates default should be used.
	
Implementation Notes:
	-Uses fork()
*/
void notify_message_async(gchar * summary, gchar * body,gchar * icon_str,glong timeout);

#endif
