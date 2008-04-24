/* -*- Mode: C; tab-width: 8; indent-tabs-mode: t; c-basic-offset: 8 -*- */
/*
 * Copyright (C) 2007 Neil J. Patel <njpatel@gmail.com>
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 * Authors: Neil J. Patel <njpatel@gmail.com>
 *
 */

#ifndef _AFF_START_H_
#define _AFF_START_H_

#include <gtk/gtk.h>

#include "affinity.h"

typedef struct _AffStart      AffStart;
typedef struct _AffStartClass AffStartClass;
typedef struct _AffStartPrivate  AffStartPrivate;

#define AFF_TYPE_START            (aff_start_get_type())
#define AFF_START(obj)            (G_TYPE_CHECK_INSTANCE_CAST((obj), AFF_TYPE_START, AffStart))
#define AFF_START_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST((klass), AFF_TYPE_START, AffStartClass))
#define AFF_IS_START(obj)         (G_TYPE_CHECK_INSTANCE_TYPE((obj), AFF_TYPE_START))
#define AFF_IS_START_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE((klass), AFF_TYPE_START))
#define AFF_START_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS((obj), AFF_TYPE_START, AffStartClass))

struct _AffStart
{
	GtkVBox parent;
};

struct _AffStartClass
{
	GtkVBoxClass parent_class;
	
	AffStartPrivate *priv;
};

G_BEGIN_DECLS

GType      aff_start_get_type(void);
GtkWidget *aff_start_new(AffinityApp *app);

void aff_start_app_launched (AffStart *start, const char *uri);

G_END_DECLS

#endif