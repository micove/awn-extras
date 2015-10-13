/*
 * Copyright (c) 2007   Rodney (moonbeam) Cryderman <rcryderman@gmail.com>
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


#ifndef __CAIRO_MENU_RENDER_
#define __CAIRO_MENU_RENDER_
#include <gtk/gtk.h>
#include "menu_list_item.h"
#include "menu.h"

enum
{
	MENU_WIDGET_NORMAL,
	MENU_WIDGET_INSET,
	MENU_WIDGET_OUTSET
};

void render_entry(Menu_list_item *entry,int max_width);
void render_directory(Menu_list_item *directory,int max_width);
void _fixup_menus(GtkFixedChild * child,GtkWidget * subwidget);
void measure_width(Menu_list_item * menu_item,int * max_width);
void render_menu_widgets(Menu_list_item * menu_item,GtkWidget * mainbox);

GtkWidget * build_menu_widget(Menu_item_color * mic, char * text,GdkPixbuf *pbuf,GdkPixbuf *pover,int max_width,int flags);

#endif
