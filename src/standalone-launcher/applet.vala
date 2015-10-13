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
 * Author : R. Cryderman <rcryderman@gmail.com>
 */

using   Gdk;
using   Gtk;
using   Awn;
using   GLib;
using   Wnck;
using   DBus;
using   Cairo;


//FIXME... ugly hack (self) to deal with vala 0.1.7 dbus signal bug
//or maybe I was just doing it wrong to begin with....
//doing this for now.
//public pointer global_self;

enum LaunchMode
{
	ANONYMOUS,
	DISCRETE
}

enum TaskMode
{
	SINGLE,
	MULTIPLE,
    NONE
}


static void print_desktop(DesktopItem desktopitem)
{

	stdout.printf("\n\nDesktop item \n");
	stdout.printf("name = %s\n",desktopitem.get_name());
//	stdout.printf("icon = \n",desktopitem.get_icon());
	stdout.printf("exec = %s\n",desktopitem.get_exec());		
	stdout.printf("\n");
}

static string get_exec(int pid)
{
    string filename=new string();
    string exec=new string();
    string after=new string();
    string orig=new string();
    int pos=0;
    bool    result;
    long   length=-1;
    filename="/proc/"+pid.to_string()+"/cmdline";        	
    try{
        result=FileUtils.get_contents(filename,out exec,out length);
    }
    catch (GLib.FileError ex){
        result=false;
    }    
    if ( result==false)
    {
        exec="false";
        length=5;
    } 
    after="";
    for(int i = 0; i<length;i++)
    {
        string temp = new string();
        temp = exec.substring(i,1);
        if (temp=="")
        {
            after=after+" ";
        }
        else
        {
            after=after+temp;
        }
    }

    return after;
}

/*static int _cmp_ptrs (pointer a, pointer b)
{
	return (int) a - (int) b;
}*/


class Configuration: GLib.Object
{
	public  			bool				anon_mode   { get; construct; }
	public			string				uid			{ get; construct; }
	protected			string				subdir;
	protected	weak	Awn.ConfigClient	primary_conf;
	protected			Awn.ConfigClient	default_conf;
	protected			Awn.ConfigClient	dummy;

	
	private				int					_task_mode;
	private				string				_active_image;
//	private				Awn.Color			_active_colour;
	private 			int					_name_comparision_len;
	private				bool				_override_app_icon;
	private             string              _desktop_file_editor;
    private             string              _advanced_text_editor;
    private             int                 _highlight_method;
    private             float               _highlight_saturate_value;
    private             int                 _max_launch_effect_reps;
    private             bool                _multi_launcher;
    private             string              _task_icon_name;
    private             int                 _task_icon_alpha;
    private             bool                _task_icon_use;

    private             string              _multi_icon_name;
    private             int                 _multi_icon_alpha;
    private             bool                _multi_icon_use;
    private             float               _multi_icon_scale;
    
    private             bool                _show_if_on_inactive;

    construct
	{
		if (anon_mode)
		{			
			default_conf=new Awn.ConfigClient.for_applet("standalone-launcher",null);
			primary_conf=default_conf;
			subdir="anonymous/";
		}
		else
		{
			default_conf=new Awn.ConfigClient.for_applet("standalone-launcher",null);
			dummy=new Awn.ConfigClient.for_applet("standalone-launcher",uid);
			primary_conf=dummy;
			subdir="discrete/";			
		}
//		_active_colour=new Awn.Color();
		read_config();
      /*      
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"active_colour", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"anonymous/override_app_icon", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"discrete/override_app_icon", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"active_task_image", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"desktop_file_editor", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"highlight_method", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"highlight_saturate_value", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"advanced_text_editor", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"max_launch_effect_reps", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"discrete/task_icon_use", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"discrete/task_icon_alpha", _config_changed, this);        
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"multi_icon_alpha", _config_changed, this);        
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"multi_icon_use", _config_changed, this);        
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"multi_icon_scale", _config_changed, this);        
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"discrete/multi_launcher", _config_changed, this);
        default_conf.notify_add(CONFIG_CLIENT_DEFAULT_GROUP,"anonymous/show_if_on_inactive", _config_changed, this);
        if (!anon_mode)
		{
				
		}*/
	}
    
/*	private static void _config_changed(Awn.ConfigClientNotifyEntry entry,Configuration ptr)
	{
        weak Configuration self = (Configuration) ptr;
        self.read_config_dynamic();
		stdout.printf("config notify fired\n");
	}
	*/
	Configuration(string uid,bool anon_mode)
	{
		this.uid=uid;
		this.anon_mode=anon_mode;
	}

    //config options that are monitored and can be dynamically changed
	private void read_config_dynamic()
    {
		_active_image=get_string("active_task_image","emblem-favorite");
		_override_app_icon=get_bool(subdir+"override_app_icon",true);
        _desktop_file_editor=get_string("desktop_file_editor","gnome-desktop-item-edit");        
        _advanced_text_editor=get_string("advanced_text_editor","gedit");
		_name_comparision_len=get_int("name_comparision_len",14);
        _highlight_method=get_int("highlight_method",2);
        _highlight_saturate_value=get_float("highlight_saturate_value",(float)2.0);
        _max_launch_effect_reps=get_int("max_launch_effect_reps",4);
        _multi_launcher=get_bool(subdir+"multi_launcher",false);
        _task_icon_name=get_string(subdir+"task_icon_name","stock_up");
        _task_icon_use=get_bool(subdir+"task_icon_use",false);
        float temp_float;
        temp_float=get_float(subdir+"task_icon_alpha",(float)0.5);
        _task_icon_alpha=(int) Math.lroundf(temp_float* (float) 255.0);

        _multi_icon_name=get_string("multi_icon_name","add");
        _multi_icon_use=get_bool("multi_icon_use",false);
        temp_float=get_float("multi_icon_alpha",(float)0.9);
        _multi_icon_alpha=(int) Math.lroundf(temp_float* (float) 255.0);
        _multi_icon_scale=get_float("multi_icon_scale",(float)0.3);
        
        _show_if_on_inactive=get_bool(subdir+"show_if_on_inactive",true);
    }

	private void read_config()
	{   
		string temp;
		_task_mode=get_int(subdir+"task_mode",1);        
		temp=get_string("active_colour","00000000");	

        _task_icon_alpha=127;

		//cairo_string_to_color(temp,_active_colour);	
        read_config_dynamic();	
	}
	
	public bool get_bool(string key,bool def=false)
	{
		bool value;
		try {
			value = default_conf.get_bool( CONFIG_CLIENT_DEFAULT_GROUP,key);
		}catch (GLib.Error ex){
			value = def;   
		}		
		return value;
	}	

	public float get_float(string key,float def=0)
	{
		float value;
		try {
			value = default_conf.get_float( CONFIG_CLIENT_DEFAULT_GROUP,key);
		}catch (GLib.Error ex){
			value = def;   
		}		
		return value;
	}

	public int get_int(string key,int def=0)
	{
		int value;
		try {
			value = default_conf.get_int( CONFIG_CLIENT_DEFAULT_GROUP,key);
		}catch (GLib.Error ex){
			value = def;   
		}		
		return value;
	}

	public string get_string(string key,string def="")
	{
		string value;
		try {
			value = default_conf.get_string( CONFIG_CLIENT_DEFAULT_GROUP,key);
		}catch (GLib.Error ex){
			value = def;   
		}		
		return value;
	}

    public bool override_app_icon{
        get { 
			return _override_app_icon;
    	}
    }

    public bool multi_launcher{
        get { 
			return _multi_launcher;
    	}
    }

    public bool task_icon_use{
        get { 
			return _task_icon_use;
    	}
    }

    public int task_mode {
        get { 
			return _task_mode;
    	}
    }

    public int highlight_method {
        get { 
			return _highlight_method;
    	}
    }

    public int task_icon_alpha {
        get { 
			return _task_icon_alpha;
    	}
    }


    public float highlight_saturate_value {
        get { 
			return _highlight_saturate_value;
    	}
    }


    public string active_image {
        get { 
			return _active_image;
    	}
    }

    public string desktop_file_editor {
        get { 
			return _desktop_file_editor;
    	}
    }

    public string task_icon_name {
        get {
			return _task_icon_name;
    	}
    }

    public string advanced_text_editor {
        get { 
			return _advanced_text_editor;
    	}
    }

	public int name_comparision_len{
        get { 
			return _name_comparision_len;
    	}
    }

	public int max_launch_effect_reps{
        get { 
			return _max_launch_effect_reps;
        }
    }

    public int multi_icon_alpha {
        get { 
			return _multi_icon_alpha;
    	}
    }

    public float multi_icon_scale {
        get { 
			return _multi_icon_scale;
    	}
    }

    public bool multi_icon_use {
        get { 
			return _multi_icon_use;
    	}
    }

    public string multi_icon_name {
        get { 
			return _multi_icon_name;
    	}
    }

    public bool show_if_on_inactive{
        get { 
			return _show_if_on_inactive;
    	}
    }
    
}


/* This class needs to be rethought*/
class DesktopFileManagement: GLib.Object 
{
    public  string uid;
    public  string directory;
    
	construct
	{
	    directory=Environment.get_home_dir()+"/.config/awn/applets/standalone-launcher/desktops/";
    }
	public string Filename()
	{
        string fullpath=directory+Checksum(uid)+".desktop";
 //       stdout.printf("Filename() = %s\n",fullpath);
		return  fullpath;
	}   
	public bool Exists()
	{
		return FileUtils.test(directory+Checksum(uid)+".desktop", FileTest.EXISTS | FileTest.IS_REGULAR);
		
	}  
	public string URI()
	{
        string fullpath="file://"+directory+Checksum(uid)+".desktop";
		return  fullpath;
	}  
    
	private string Checksum(string str)
	{
	    string result=new string();
 //       stdout.printf("DesktopFileManagement checksum \n");          
	    result="anon-";
	    for(int i=0;i<str.len();i++)
	    {
	        string piece = str.substring(i,1);  //FIXME...  easy in C.. not sure of vala.
	        if (
	                (piece=="%") ||    (piece==".") || (piece=="?") || (piece=="*") 
	                ||  (piece=="&") || (piece=="~") || (piece=="@") || (piece==";")
	                ||  (piece=="(") || (piece=="\\")|| (piece=="/")
	                ) 
	        {
	            piece="_";
            }	            
	        result=result+piece;
	    }
	    return result;
	}    
    
/*	protected  string  directory;
	public     string  _uid {get; construct;  }
    private    string userid;
	
	construct
	{
		directory=Environment.get_home_dir()+"/.config/awn/applets/standalone-launcher/desktops/";
		if ( _uid.to_double()>0)
		{
			if (! FileUtils.test(directory,FileTest.EXISTS)  )
			{		
				if ( DirUtils.create_with_parents(directory,0777) != 0)
				{
					error("Fatal error creating %s\n",directory);
				}
			}
			else if (!FileUtils.test(directory,FileTest.IS_DIR))
			{
				//FIXME... throw an exception... it has to be a dir.
			}

		}
        userid=Checksum(_uid);
	}

    
	public string uid{
        set{
            stdout.printf("DesktopFileManagement uid \n");      
            userid=Checksum(value);
        }
	}
	
	private string Checksum(string str)
	{
        return str;
	    string result=new string();
        stdout.printf("DesktopFileManagement checksum \n");          
	    result="anon-";
	    for(int i=0;i<str.len();i++)
	    {
	        string piece = str.substring(i,1);  //FIXME...  easy in C.. not sure of vala.
	        if (
	                    (piece==".") || (piece=="?") || (piece=="*") 
	                ||  (piece=="&") || (piece=="~") || (piece=="@") || (piece==";")
	                ||  (piece=="(") || (piece=="\\")|| (piece=="/")
	                ) 
	        {
	            piece="_";
            }	            
	        result=result+piece;
	    }
	    return result;
	}
	
	public DesktopFileManagement(string _uid)
	{    
		this._uid = _uid;
	}
	
	public string URI()
	{
        string fullpath="file://"+directory+userid+".desktop";
		return  fullpath;
	}

	public string Filename()
	{
        string fullpath=directory+userid+".desktop";
		return  fullpath;
	}
	
	public bool Exists()
	{
		return FileUtils.test(directory+userid+".desktop", FileTest.EXISTS | FileTest.IS_REGULAR);
		
	}*/
}


//[DBusInterface (name = "org.awnproject.taskmand")]
//interface Taskman.TaskmanInterface;

//[DBus (name = "org.awnproject.taskmand")]


public class DBusComm : AppletSimple
{
        public		DBus.Connection		conn;
		public      dynamic DBus.Object server_object;
    
        construct
        {
            conn = DBus.Bus.get(DBus.BusType.SESSION);
            server_object = conn.get_object ("org.awnproject.taskmand", "/org/awnproject/taskmand", "org.awnproject.taskmand");
//            server_object.Offered += _offered;
        }
    
/*        private void _offered (dynamic DBus.Object obj,string xid)
        {
        // dbus signal handler

            message ("Message received %s *****************\n", xid);
        }
  */      

		public void Launcher_Register(string uid)
		{	
  //          stdout.printf("Launcher_Register\n");
            try{
			    server_object.Launcher_Register(uid);
            }
            catch (GLib.Error ex){
                stderr.printf("D-Bus Error Launcher_Register()\n");
            }            
		}
		
		public void Launcher_Unregister(string uid)
		{
            try{
			    server_object.Launcher_Unregister(uid);
            }
            catch (GLib.Error ex){
                stderr.printf("D-Bus Error Launcher_Unregister()\n");
            }
                
		}
		
		public string Inform_Task_Ownership(string uid, string xid, string request)
		{
			string response;
			response=server_object.Inform_Task_Ownership(uid,xid,request);
			return response;
		}

		public string Return_XID(string uid, string xid)
		{
			server_object.Return_XID(uid,xid);
            return xid;
		}
}

class DiagButton: Gtk.Button
{
    //FIXME... make into properties.
	public		Wnck.Window		win				{ get; construct; }
	public		Gtk.Widget		container		{ get; construct; }
	public		int				icon_size		{ get; construct; }     

    
	construct
	{
		weak Gdk.Pixbuf pbuf;
		if (! win.get_icon_is_fallback() )
		{
			weak Gdk.Pixbuf pbuf;
			pbuf=win.get_icon();
			pbuf=pbuf.scale_simple (icon_size-2, icon_size-2, Gdk.InterpType.BILINEAR );
		}	
		if (pbuf==null)
		{
			pbuf=win.get_icon();
		}
		Gtk.Image   image=new Gtk.Image.from_pixbuf(pbuf);
		set_label(win.get_name() );
		set_image(image);
		this.button_press_event += _clicked;	
	}
	
	DiagButton(Wnck.Window win,Gtk.Widget container,int icon_size) 
    {
        this.win = win;
        this.container = container;
        this.icon_size = icon_size;
    }
	
    private bool _clicked(Gtk.Widget widget,Gdk.EventButton event)
    {
		if (win.is_active() )
		{
			win.minimize();
		}
		else
		{
			win.activate(Gtk.get_current_event_time());
		}
		container.hide();
		return true;
	}
}


//--------------------------------------------------------------

class DesktopitemButton: Gtk.Button
{
	public		weak    DesktopItem     item			{ get; construct; }
//FIXME... make into properties.
	public		Gtk.Widget		container		{ get; construct; }
	public		int				icon_size		{ get; construct; }     
    public      IconTheme		theme           { get; construct; }
 

	construct
	{
		Gdk.Pixbuf pbuf;
        pbuf = new Pixbuf.from_file_at_scale(item.get_icon(theme),icon_size-2,-1,true );//FIXME 
        if (pbuf !=null)
        {
            pbuf=pbuf.scale_simple (icon_size-2, icon_size-2, Gdk.InterpType.BILINEAR );
            Gtk.Image   image=new Gtk.Image.from_pixbuf(pbuf);
            this.set_image(image);
        }
        this.set_label(item.get_name() );
        this.set_relief(ReliefStyle.NONE);
		this.button_press_event += _clicked;	
	}
	
	DesktopitemButton(DesktopItem item,Gtk.Widget container,IconTheme theme,int icon_size) 
    {
        this.item = item;
        this.container = container;
        this.icon_size = icon_size;
        this.theme = theme;
    }
	
    private bool _clicked(Gtk.Widget widget,Gdk.EventButton event)
    {
        SList<string>	documents;
        item.launch(documents);
		container.hide();
		return true;
	}
}


enum Ownership
{
	CLAIM,
	ACCEPT,
    DENY
}

//------------------------------------------------------------------------------

enum ListingResult
{
    NOMATCH,
    BLACKLISTED,
    WHITELISTED
}

class Listing : GLib.Object
{
//There will be an advanced mode and simple mode.
//overkill in general but it's not that much extra work at this point.
    protected   List<string>               blacklist_titles_global;
    protected   List<string>               blacklist_exec_global;

    protected   List<string>               whitelist_titles_pre;
    protected   List<string>               whitelist_exec_pre;
    protected   List<string>               blacklist_titles;
    protected   List<string>               blacklist_exec;
    protected   List<string>               whitelist_titles_post;
    protected   List<string>               whitelist_exec_post;

    public      string                      listingfile { get; construct; }
    protected   string                      directory;


    public string filename_whitelist_pre() 
    {
			return directory+listingfile+".whitelist.pre";
    }

    public string filename_blacklist() 
    {
			return directory+listingfile+".blacklist";
    }

    construct
    {

		    directory=Environment.get_home_dir()+"/.config/awn/applets/standalone-launcher/lists/";
        if (! FileUtils.test(directory,FileTest.EXISTS)  )
        {		
            if ( DirUtils.create_with_parents(directory,0777) != 0)
            {
                error("Fatal error creating %s\n",directory);
            }
        }
        else if (!FileUtils.test(directory,FileTest.IS_DIR))
        {
            //FIXME... throw an exception... it has to be a dir.
        }      
        
        //FIXME...  this was a lot cleaner before vala v 0.17
        whitelist_titles_pre=read_list_title(directory+listingfile+".whitelist.pre");
        whitelist_titles_pre.prepend("thisisadummystringtosupppressanASSERTION");
        whitelist_exec_pre=read_list_exec(directory+listingfile+".whitelist.pre");
        whitelist_exec_pre.prepend("thisisadummystringtosupppressanASSERTION");      
        blacklist_titles_global=read_list_title(Environment.get_home_dir()+"/.config/awn/applets/standalone-launcher/blacklist");
        blacklist_titles_global.prepend("thisisadummystringtosupppressanASSERTION");        
        blacklist_exec_global=read_list_exec(Environment.get_home_dir()+"/.config/awn/applets/standalone-launcher/blacklist");
        blacklist_exec_global.prepend("thisisadummystringtosupppressanASSERTION");         
        blacklist_titles=read_list_title(directory+listingfile+".blacklist");
        blacklist_titles.prepend("thisisadummystringtosupppressanASSERTION");      
        blacklist_exec=read_list_exec(directory+listingfile+".blacklist");
        blacklist_exec.prepend("thisisadummystringtosupppressanASSERTION");       
        whitelist_titles_post=read_list_title(directory+listingfile+".whitelist.post");
        whitelist_titles_post.prepend("thisisadummystringtosupppressanASSERTION");        
        whitelist_exec_post=read_list_exec(directory+listingfile+".whitelist.post");
        whitelist_exec_post.prepend("thisisadummystringtosupppressanASSERTION");        
/*        read_list(Environment.get_home_dir()+"/.config/awn/applets/standalone-launcher/blacklist",ref blacklist_titles_global,ref blacklist_exec_global);    
        read_list(directory+listingfile+".blacklist",ref blacklist_titles,ref blacklist_exec);
        read_list(directory+listingfile+".whitelist.post",ref whitelist_titles_post,ref whitelist_exec_post);
*/
    }

    //FIXME...  this was a lot cleaner before vala v 0.17
    List<string> read_list_exec(string file_name)
    {
        List<string> result;
        string[] file_strings;
        string file_data;
      
        try{
            FileUtils.get_contents (file_name, out file_data);
        }catch (FileError ex ){
//            stdout.printf("no whitelist: '%s'\n",directory+listingfile+".whitelist.pre");
            file_data="";
        }
        file_strings=file_data.split("\n");
        foreach(string entry in file_strings)
        {
            if (entry.substring(0,6)=="TITLE:" )
            {
                entry=entry.substring(6,entry.len() );
                result.prepend(entry);
            }
        }
        return result;
    }

    //FIXME...  this was a lot cleaner before vala v 0.17
    List<string> read_list_title(string file_name)
    {
        List<string> result;
        string[] file_strings;
        string file_data;
        try{
            FileUtils.get_contents (file_name, out file_data);
        }catch (FileError ex ){
//            stdout.printf("no whitelist: '%s'\n",directory+listingfile+".whitelist.pre");
            file_data="";
        }
        file_strings=file_data.split("\n");
        foreach(string entry in file_strings)
        {
            if (entry.substring(0,6)=="TITLE:" )
            {
                entry=entry.substring(6,entry.len() );
                result.prepend(entry);
            }
        }
        return result;
    }

    Listing(string listingfile)
    {
            this.listingfile=listingfile;
    }

    protected bool check_list(List<string> list,string value)
    {
        if ( (value !=null) && (list!=null))
        {
            foreach (string pattern in list)
            {
                //stdout.printf("CHECKING %s = %s \n",pattern,value);
                if ( Regex.match_simple(pattern, value) )
                {
                    return true;
                }
            }
        }
        return false;
    }


    public ListingResult check_listings(string title, string exec)
    {
       //stdout.printf("title = %s, exec = %s",title,exec);
        if (        check_list(whitelist_titles_pre,title)  ||
                    check_list(whitelist_exec_pre,exec) )
        {
            return ListingResult.WHITELISTED;
        }        
        if (        check_list(blacklist_titles_global,title)   ||
                    check_list(blacklist_exec_global,exec)      ||
                    check_list(blacklist_titles,title)          ||
                    check_list(blacklist_exec,exec) )
        {
            return ListingResult.BLACKLISTED;
        }
        if (        check_list(whitelist_titles_post,title)  ||
                    check_list(whitelist_exec_post,exec) )
        {
            return ListingResult.WHITELISTED;
        }        
        return ListingResult.NOMATCH;
    }
}

class BookKeeper : GLib.Object 
{
	protected	SList<ulong>			    XIDs;
	protected	SList<ulong>			    PIDs;	
	protected   SList<Wnck.Window>		    wins;
    protected   SList<Wnck.Window>		    removed_wins;
	protected   SList<Wnck.Application>	    apps;
    protected   SList<string>               names;
    protected   SList<string>               execs;
    protected   Wnck.Screen                 wnck_screen;

    construct 
    { 
        wnck_screen = Wnck.Screen.get_default();	
        wnck_screen.force_update();	
    }

    public uint number()
    {
        cleanup();
        return wins.length();
    }

    public Ownership what_to_do(Wnck.Window win)
    {
        cleanup();
        if (find_pid(win.get_pid() ) )
        {
            return Ownership.CLAIM;
        }
        if (find_xid(win.get_xid() ) )
        {
            return Ownership.CLAIM;
        }
        if (find_app(win.get_application() ) )
        {
            return Ownership.CLAIM;
        }
        if (find_name(win.get_name() ))
        {
            return Ownership.ACCEPT;
        }
        if (find_name( (win.get_application()).get_name() ) )
        {
            return Ownership.ACCEPT;
        }
        if (find_exec(get_exec(win.get_pid()) ))
        {
            return Ownership.ACCEPT;
        }
        return  Ownership.DENY;
    }

    public weak SList<Wnck.Window> get_wins()
    {
        return wins;
    }
    
    public void    update_with_xid(ulong xid)
    {
        cleanup();
        Wnck.Window win;
        add_xid(xid);
        win=search_win_by_xid(xid);
        add_win(win);
        add_app(get_app_from_win(win) );
        add_pid(win.get_pid());
        add_names_with_win(win);
        add_exec(get_exec(win.get_pid()));
    }

    public void    update_with_pid(ulong pid)
    {
        cleanup();
        add_pid(pid);
    }

    public void    update_with_win(Wnck.Window win)
    {
        cleanup();
        add_win(win);
        add_xid(win.get_xid());
        add_pid(win.get_pid());
    }

    public void    update_with_app(Wnck.Application app)
    {
        cleanup();         
        add_pid(app.get_pid());
    }

    public void    update_with_name(string name)
    {
        cleanup();
        add_name(name);
    }

    public  void    update_with_desktopitem(DesktopItem item)
    {
        cleanup();        
        add_exec(item.get_exec());
        add_name(item.get_name());
    }

    public  bool visible()
    {
        cleanup();
        return (number()>0);
    }

    Wnck.Application  get_app_from_win(Wnck.Window win)
    {
        if (win!=null)
        {
            return win.get_application();
        }
        return null;
    }

    public void cleanup()
    {
        int i;
        foreach(ulong xid in XIDs)
        {
            Wnck.Window win;
            win=search_win_by_xid(xid);
            if (win !=null )
            {
                add_win(win);
            }
        }
        //FIXME ?? at some point consider pruning removed_wins.

        for(i=0;i<wins.length();i++)
        {
            if ( search_win_by_win( wins.nth_data(i) )==null)
            {
                removed_wins.prepend(wins.nth_data(i));
                wins.remove_all(wins.nth_data(i) );
                i--;
            }
        }
        foreach(Wnck.Window win in removed_wins)
        {
            if (search_win_by_win(win)!=null )
            {
                wins.prepend(win);
                removed_wins.remove(win);
            }
        }
    }

    //needle is a pointer because it may not be a Wnck.Window anymore... no harm done
    public Wnck.Window search_win_by_win(Wnck.Window needle)
    {
        if (needle==null)
            return null;
		weak	GLib.List	<Wnck.Window>	windows;
		windows=wnck_screen.get_windows();
        weak    GLib.List   <Wnck.Window>   result;
        result = windows.find(needle);
        if (result==null)
        {
            return null;
        }
        else
        {
            return (Wnck.Window)needle;
        }
    }


    //search all wnck windows
    private Wnck.Window  search_win_by_xid(ulong needle)
    {
		weak	GLib.List	<Wnck.Window>	windows;
		windows=wnck_screen.get_windows();
		foreach (Wnck.Window win in windows)
		{
			if (win.get_xid() == needle)
			{
				return win;
			}		
		}
		return null;
    }
    
    //search wnck windows
    private Wnck.Window  search_win_by_pid(ulong pid)
    {
		weak	GLib.List	<Wnck.Window>	windows;
		windows=wnck_screen.get_windows();
		foreach (Wnck.Window win in windows)
		{
			if (win.get_pid() == pid)
			{
				return win;
			}		
		}
		return null;
    }

    public Wnck.Window find_win_by_xid(ulong xid)
    {
		foreach (Wnck.Window win in wins)
		{
			if (win.get_xid() == xid)
			{
				return win;
			}		
		}
		return null;
    }

    private bool find_xid(ulong needle)
    {
        return (XIDs.find(needle) !=null);
    }

    public bool find_pid(ulong needle)
    {
        return (PIDs.find(needle) !=null);
    }

    public bool find_win(Wnck.Window needle)
    {
        return (wins.find(needle) !=null);
    }

    public bool find_app(Wnck.Application needle)
    {
        return (apps.find(needle) !=null);
    }

    public bool find_name(string needle)
    {
        if (needle==null)
            return false;
        long len1=needle.len();
        foreach(string name in names)
        {
            long len2 = name.len();
            string left;
            string right;
            if (len1>len2)
            {
                left=needle.substring(0,len2);
                right=name.substring(0,len2);
            }
            else
            {
                left=needle.substring(0,len1);
                right=name.substring(0,len1);
            }            
            if (left==right)
            {
                return true;
            }
        }
        return false;
    }

    public bool find_exec(string needle)
    {
        if (needle==null)
            return false;
        string [] arr=needle.split("%");
        needle=arr[0];
        needle=needle.chomp();
        foreach(string exec in execs)
        {
            if (exec==needle)
            {
                return true;
            }
        }
        return false;
    }

    private void add_names_with_win(Wnck.Window win)
    {
        add_name(win.get_name());
        add_name(get_app_from_win(win).get_name() );
    }

    private void add_pid(ulong pid)
    {
        if (pid!=0)
        {
            if (!find_pid(pid) )
            {
                PIDs.prepend(pid);
            }
        }
    }


    private void add_xid(ulong xid)
    {
        if (xid!=0)
        {
            if (!find_xid(xid) )
            {
                XIDs.prepend(xid);
            }
        }
    }

    private void add_win(Wnck.Window win)
    {
        if (win != null)
        {
            if (!find_win(win) )
            {
                wins.prepend(win);
            }
        }
    }

    private void add_app(Wnck.Application app)
    {
        if (app != null)
        {
/*            if (!find_app(app) )
            {
                wins.prepend(app);
            }*/
        }
    }

    private void add_name(string name)
    {
        if (name!=null)
        {
            if (!find_name(name) )
            {
                if ( (name!="None") && (name!="") )
                {
                    names.prepend(name);
                }
            }
        }            
    }

    private void add_exec(string exec)
    {
        if (exec!=null)
        {
            string [] arr=exec.split("%");
            exec=arr[0];
            exec=exec.chomp();
            if (!find_exec(exec) )
            {
                if (exec!="false")
                {
                    execs.prepend(exec);
                }
            }
        }
    }
}

//------------------------------------------------------------------------------

class Multi_Launcher:    GLib.Object
{
    protected           SList <DesktopItem>        items;
    public     weak    SList <string>             desktop_filenames { get; construct; }

    construct
    {        
        foreach(string filename in desktop_filenames)
        {	
            items.append(new DesktopItem(filename ));
        }
    }

    public Multi_Launcher(GLib.SList<string> desktop_filenames)
    {
        this.desktop_filenames=desktop_filenames;
    }

    public void add_file(string filename)
    {
       //desktop_filenames.append(filename);
       items.append(new DesktopItem(filename));
    }

    public uint number()
    {
        return items.length();
    }

    public weak SList<DesktopItem> desktops()
    {
        return items;
    }
/*
    public void prepend(ref DesktopItem item)
    {
        items.prepend(item);
    }

    public void append(ref DesktopItem item)
    {
        items.append(item);
    }
*/


}

//------------------------------------------------------------------------------

class LauncherApplet : DBusComm
{
    protected   BookKeeper              books;

    protected	IconTheme				theme;
    protected	Pixbuf					icon;
    protected	Pixbuf					task_icon;
    protected	Pixbuf                  multi_emblem_icon;
    protected   Gtk.Window				dialog;
    protected   Gtk.VButtonBox			vbox;
    protected	DesktopItem				desktopitem;//primary item
    protected   Configuration			config;
	protected	TargetEntry[]			targets;
	protected   Wnck.Screen				wnck_screen;
	protected   DesktopFileManagement   desktopfile;
	protected   int						launchmode;
//	protected   DBusComm				dbusconn;
	protected   ConfigClient			awn_config;
	protected   SList<ulong>			retry_list;	
	protected   Awn.Title               title;
	protected   weak Awn.Effects        effects;
	protected   string                  title_string;
	protected   bool                    hidden;
	protected   int                     timer_count;
    protected   Gtk.Menu                right_menu;	
    protected   bool                    activated;
    protected   Listing                 listing;
    protected   bool                    closing;
    protected   Multi_Launcher          multi_launcher;
    protected   uint                    dnd_motion_last_time;

    construct 
    { 
//        global_self=this;
        closing=false;  //if this becomes true it means an irrevocable closing is in process.
        timer_count=0;
        blank_icon();
		this.realize += _realized;        
		hidden=true;
        dnd_motion_last_time=0;
 //       stdout.printf("construct\n");
    }

    /*sets the icon to a blank icon*/
    private void blank_icon()
    {
        Pixbuf  hidden_icon;       
        set_size_request( height, -1);
        icon=new Pixbuf( Colorspace.RGB,true, 8, height-2,height-2);
        icon.fill( 0x00000066);
        set_icon(icon);
    }

    /*sets icon to a 2x2 transparent icon*/
    private void hide_icon()
    {
        if (hidden)
        {
            Pixbuf  hidden_icon;      
            //set_size_request( 1, 1);
            effects.draw_set_window_size(1,1);
            hidden_icon=new Pixbuf( Colorspace.RGB,true, 8, 1,1);
            hidden_icon.fill( 0x00000000);
            set_icon(hidden_icon);
            hide();
        }            
    }

    /*callback function - double checks to be sure icon should be hidden*/
    private bool _hide_icon()
    {
        if(!books.visible() )
        {
            if ( launchmode == LaunchMode.ANONYMOUS )
            {
                hidden=true;
                hide_icon();
            }
        }
        return false;
    }
    
    private void show_icon()
    {
        uint num=0;
        if (!hidden)
        {

            Pixbuf temp;
            show_all();
            set_size_request(height, -1);    //not really necessary
            if (activated)
            {
                temp=highlight_icon();
            }
            else
            {
                temp=icon.copy();
            }
            num=books.number();
            if (config.task_icon_use && (num>0) && (launchmode==LaunchMode.DISCRETE))
            {                       //FIXME
                if (task_icon != null)
                {
                    //Pixbuf task;
                    //task=task_icon.copy();
                    task_icon.composite(temp,0, 0, height-2,height-2,0,0,1.0,1.0, Gdk.InterpType.BILINEAR,config.task_icon_alpha);
                    //temp=task.copy();
                }
            }
            if (config.multi_icon_use && (num>1) )
            {
                int scaled_size=(int) ((height - 2)*config.multi_icon_scale);
                multi_emblem_icon.composite(temp,
                                0,0,
                                height-2,height-2,
                                (height-2)-scaled_size , (height-2)-scaled_size,
                                config.multi_icon_scale,config.multi_icon_scale, Gdk.InterpType.BILINEAR,config.multi_icon_alpha);
            }
            if (temp!=null)    
            {
                set_icon(temp);
                temp.unref();
            }
        }
    }    

    private Pixbuf highlight_icon()
    {
        float saturate=(float)1.0;
        bool    pixelate=false;
        
        Pixbuf temp=icon.copy();
        
        if ( (config.highlight_method & 0x1) > 0)
        {
            saturate=config.highlight_saturate_value;
        }
        pixelate=((config.highlight_method & 0x2) > 0);
        //FIXME  minor optimization - don't do if both options off.
        temp.saturate_and_pixelate (temp, saturate, pixelate);
        return temp;
    }

    private bool _initialize()
    {
    //    stdout.printf("_initialize\n");
        books = new BookKeeper();
        multi_launcher = null;
        this.button_press_event+=_button_press;
        this.scroll_event+=_scroll_event;
        activated=false;
        hidden=false;
		targets = new TargetEntry[2];
		targets[0].target = "text/uri-list";
		targets[0].flags = 0;
		targets[0].info =  0;
		targets[1].target = "text/plain";
		targets[1].flags = 0;
		targets[1].info =  0;

        drag_source_set(this,Gdk.ModifierType.BUTTON1_MASK,targets, Gdk.DragAction.COPY);
		drag_dest_set(this, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.COPY);
		this.drag_data_received+=_drag_data_received;
        this.drag_data_get+=_drag_data_get;
        this.drag_motion+=_drag_motion;
        this.drag_leave+=_drag_leave;
  //      stdout.printf("_initialize...2\n");        
		awn_config= new ConfigClient();
        config=new Configuration(uid,(uid.to_double()<=0));
        if (config.task_mode != TaskMode.NONE)
        {
   //         stdout.printf("_initialize...3.0\n");              
            this.enter_notify_event+=_enter_notify;
            this.leave_notify_event+=_leave_notify;
 //           stdout.printf("_initialize...3.2\n");                          
            dialog=get_dialog(true);
            dialog.set_accept_focus(false);
            dialog.set_app_paintable(true);
 //           stdout.printf("_initialize...3.6\n");                          
            vbox=new VButtonBox();
            dialog.add(vbox);
            build_right_click();
 //           stdout.printf("_initialize...3.8\n");                          
//            dbusconn = new DBusComm();
 //           stdout.printf("_initialize...3.8.1\n");            
            Launcher_Register(uid);
//            stdout.printf("_initialize...3.8.2\n");                        
            server_object.Offered+=_offered;
 //           stdout.printf("_initialize...3.8.3\n");                        
            wnck_screen = Wnck.Screen.get_default();	
  //          stdout.printf("_initialize...3.8.4\n");                        
            wnck_screen.force_update();	
        }
 //       stdout.printf("_initialize...4\n");         
        theme = IconTheme.get_default ();        
		icon = theme.load_icon ("stock_stop", height - 2, IconLookupFlags.USE_BUILTIN);
		title_string = new string();
		title = new Awn.Title();
		title = (Awn.Title) Awn.Title.get_default();

        effects=get_effects();
        if (effects == null)
        {
            stdout.printf("ERROR------------------------------\n");
        }
        effects.draw_set_window_size(height,height);
        effects.draw_set_icon_size(height-2,height-2);
		show_icon();
 //       stdout.printf("_initialize...6\n");         
		if (uid.to_double()>0) 
		{				
  //          stdout.printf("_initialize...6.1\n");              
//            desktopfile = new DesktopFileManagement(uid);
            desktopfile = new DesktopFileManagement();
            desktopfile.uid = uid;
 //           stdout.printf("_initialize...6.2\n");                          
			launchmode = LaunchMode.DISCRETE;
  //          stdout.printf("_initialize...6.3\n");                          
			desktopitem = new DesktopItem(desktopfile.Filename() );	
  //          stdout.printf("_initialize...7.3\n");               
			if (!desktopfile.Exists() )
			{
 //               stdout.printf("_initialize...7.3.1\n");                               
				desktopitem.set_exec("false");
				desktopitem.set_icon("stock_stop");
				desktopitem.set_item_type("Application");
				desktopitem.set_name("None");
			}
            else
            {
  //              stdout.printf("_initialize...7.5\n");                               
                books.update_with_desktopitem(desktopitem);
            
                if (config.multi_launcher)
                {
                    GLib.SList <string> launchers;
                    string  desktop_key=desktopitem.get_string("X-AWN-StandaloneLauncherDesktops");
                    if (desktop_key==null)
                    {
                        desktop_key="";
                    }
//                    stdout.printf("_initialize...7.6\n");                                                   
                    string []desktop_files=desktop_key.split(":");            
                    launchers.prepend(desktopfile.Filename());
                    foreach(string filename in desktop_files)
                    {
                        launchers.prepend(filename);
                    }
                    multi_launcher = new Multi_Launcher( launchers);
 //                   stdout.printf("_initialize...7.7\n");                                                   
                    foreach(weak DesktopItem item in multi_launcher.desktops() )
                    {
                        books.update_with_desktopitem(item);
                    }
                }                
            }
    		title_string = desktopitem.get_name();
            listing = new Listing(GLib.Path.get_basename(desktopfile.Filename()));
		}
		else
		{
			launchmode = LaunchMode.ANONYMOUS;
            ulong   xid=uid.substring(1,128).to_ulong();
            books.update_with_xid(xid);    
            Wnck.Window win=find_win_by_xid(xid);
		    if (win!=null)
		    {		    
				string response;
				response=Inform_Task_Ownership(uid,win.get_xid().to_string(),"CLAIM");
                if (response==null)
                {			               
                    stdout.printf("response == null. exiting\n");
                    close();
                }

                while(response!="MANAGE")
				{
                    hidden=false;
					while (response=="RESET")
					{
						Launcher_Register(uid);					
						response=Inform_Task_Ownership(uid,win.get_xid().to_string(),"CLAIM");					
					}
					if (response=="HANDSOFF")
					{
						close();
					}			
				}
				set_anon_desktop(win);
                if (desktopitem==null)
                {			               
                    stdout.printf("desktopitme == null. exiting\n");
                    close();
                }
                listing = new Listing(GLib.Path.get_basename(desktopfile.Filename()));
                if (listing.check_listings(win.get_name(),get_exec(win.get_pid()))==ListingResult.BLACKLISTED)
                {
                    close();
                }

                books.update_with_desktopitem(desktopitem);
				win.name_changed+=_win_name_change;
				win.state_changed+=_win_state_change;				
                title_string=win.get_name();
				icon=win.get_icon();		//the fallback	
                if (icon==null)
                {
                    icon=(win.get_application()).get_icon();
                }
				if (icon !=null)
				{
					icon=icon.scale_simple (height-2, height-2, Gdk.InterpType.BILINEAR );
					show_icon(); 
				}
		    }			
		    else
		    {
				close();
		    }
		}	
//        stdout.printf("_initialize...16\n"); 
		if (desktopitem.exists() )  //we will use a user specified one if it exists.
		{
			if (desktopitem.get_icon(theme)!=null)
			{
				icon = new Pixbuf.from_file_at_scale(desktopitem.get_icon(theme),height-2,-1,true );//FIXME - throws
			}		
		}	
        if (config.task_mode != TaskMode.NONE)
        {
            wnck_screen.window_closed+=_window_closed;
            wnck_screen.window_opened+=_window_opened;		
            wnck_screen.application_closed+=_application_closed;
            wnck_screen.application_opened+=_application_opened;	
            wnck_screen.active_window_changed+=	_active_window_changed;
        }
        wnck_screen.active_workspace_changed+=_active_workspace_changed;
//        stdout.printf("_initialize...18\n"); 
		task_icon = theme.load_icon (config.task_icon_name, height - 2, IconLookupFlags.USE_BUILTIN);
        if (task_icon == null)
        {
            task_icon=new Pixbuf( Colorspace.RGB,true, 8,height-2,height-2);
            task_icon.fill(0x2020D0ff);
        }

		multi_emblem_icon = theme.load_icon (config.multi_icon_name,height-2, IconLookupFlags.USE_BUILTIN);
        if (multi_emblem_icon == null)
        {
            multi_emblem_icon=new Pixbuf( Colorspace.RGB,true, 8,height-2,height-2);
            multi_emblem_icon.fill(0x20D020ff);
        }

        show_icon();        
        effects.start_ex(Effect.LAUNCHING,null,null,1);
        desktopitem.set_string ("Type","Application");         
 //       stdout.printf("_initialize....20\n");        
		return false;
    }
    
    public LauncherApplet(string uid, int orient, int height) 
    {
        this.uid = uid;
        this.orient = orient;
        this.height = height;
    }

    private AppletDialog get_dialog(bool use_awn)
    {
        AppletDialog d;
        d=new AppletDialog(this);
        
        return d;
    }
    private string _get_title()
    {
        return title_string;
    }    

    private void set_anon_desktop(Wnck.Window win)
    {
        string  temp=new string();
		string  exec=new string();    
		Wnck.Application app=win.get_application();	
		if (app.get_name()!=null)
		{
		    temp=app.get_name();
//            desktopfile = new DesktopFileManagement(temp);
            desktopfile = new DesktopFileManagement();            
			desktopfile.uid = temp ;		
		}
		else
		{
		    temp=win.get_name();
//		    desktopfile = new DesktopFileManagement(temp);	
		    desktopfile = new DesktopFileManagement();	
			desktopfile.uid = temp;
		}		
		desktopitem = new DesktopItem(desktopfile.Filename() );
        desktopitem.set_string ("Type","Application");	
        try{
            desktopitem.save(desktopfile.URI());
        }catch (GLib.Error ex) {
            stderr.printf("Non Fatal error. failed to write desktop file\n");
        }
//        desktopitem = new DesktopItem(desktopfile.Filename() );        
		desktopitem.set_name(temp);
    

		if (! desktopitem.exists() )		
		{
			desktopitem.set_icon("none");
			desktopitem.set_item_type("Application");
			desktopitem.set_exec("false");			
		}

        
		string filename=new string();
		if (win.get_pid() != 0)
		{
		    bool result;
            exec=get_exec(win.get_pid());
            if (exec != "false")
            {
                desktopitem.set_exec(exec);
                try{
                    desktopitem.save(desktopfile.URI() );
                }catch(GLib.Error ex){
                    stderr.printf("error writing file %s\n",desktopfile.Filename());
                }
                if ( (desktopitem.get_string("Icon")=="none") ||
                    (desktopitem.get_string("Icon")==null) )
                {
                    desktopitem.set_icon(GLib.Path.get_basename(exec));			
                }		
            }
        }
        else
        {
        
        }
        try{
    		desktopitem.save(desktopfile.URI() );	
    	}catch(GLib.Error ex){
    	    stderr.printf("error writing file %s\n",desktopfile.Filename());
    	}
        desktopitem.set_string ("Type","Application");		    	
//        desktopitem.save(desktopfile.Filename());    	
//		desktopitem = new DesktopItem(desktopfile.Filename() );						
    }
        
    private void close()
    {
		string needle;
		stdout.printf("Closing uid = %s\n",uid);
		weak SList<string> applet_list;
		int fd_lock=Awn.ConfigClient.key_lock_open(Awn.CONFIG_CLIENT_DEFAULT_GROUP,"applets_list");
		if (fd_lock!=-1)
		{
			Awn.ConfigClient.key_lock(fd_lock,1);
		    Launcher_Unregister(uid);
			applet_list = awn_config.get_list (Awn.CONFIG_CLIENT_DEFAULT_GROUP,"applets_list", Awn.ConfigListType.STRING) ;
			needle="standalone-launcher.desktop::"+uid;

		    for ( int i = 0; i < applet_list.length(); i++) 
		    {
				if( applet_list.nth_data(i).str(needle) !=null)
				{
		            applet_list.delete_link(applet_list.nth(i) );
		            i=0;
				}
		    }
            try{
                awn_config.set_list(Awn.CONFIG_CLIENT_DEFAULT_GROUP,"applets_list", Awn.ConfigListType.STRING,applet_list);
            }catch (GLib.Error ex ){
                stderr.printf("Failed to write applet_list... exiting anyway\n");
            }
			Awn.ConfigClient.key_lock_close(fd_lock);
		}						
		Thread.exit(null);
		assert_not_reached ();
    }

    //FIXME... ugly hack (self) to deal with vala 0.1.7 dbus signal bug
    //or maybe I was just doing it wrong to begin with....
    //doing this for now.
    private void _offered(dynamic DBus.Object obj,string xid)
    {
//        stdout.printf("_offered\n");
        LauncherApplet applet= this;
        Wnck.Window window=applet.find_win_by_xid(xid.to_ulong() );
        if (window!=null)
        {
            applet._window_opened(applet.wnck_screen,window);
        }
    }
     
    
    private bool _drag_motion(Gtk.Widget widget,Gdk.DragContext context, int x, int y, uint time)
    {
//        stdout.printf("Drag motion... enter\n");        
        
        if ( dnd_motion_last_time == 0)
        {
            activate_next_win(time);
            if ( books.number()==1)
            {
 //               stdout.printf("Drag motion - change\n");            
            }
            else if ( books.number()>1)
            {
                button_dialog(2);
 //               stdout.printf("Drag motion - multi\n");            
            }
            dnd_motion_last_time=time;                        
        }
		return true;
    }  

    private void _drag_leave (Gtk.Widget widget,Gdk.DragContext context, uint time_)
    {
 //       stdout.printf("Drag leave\n");
        dnd_motion_last_time=0;        
    }  
    
    private bool _drag_drop(Gtk.Widget widget,Gdk.DragContext context,int x,int y,uint time)
    {
		return true;
    }  

    private void _drag_data_get  (Gtk.Widget widget,Gdk.DragContext context, Gtk.SelectionData selection_data, uint info, uint time_)
    {    
  //      stdout.printf("_drag_data_get\n");
        selection_data.set_text("test data\n",-1);
    }

    private void _drag_data_received(Gtk.Widget widget,Gdk.DragContext context,int x,int y,Gtk.SelectionData selectdata,uint info,uint time)
    {    
 //       stdout.printf("drag data received\n");
		weak SList <string>	fileURIs;
		string  cmd;  
		bool status=false;
		fileURIs=vfs_get_pathlist_from_string((string)selectdata.data);
		foreach (string str in fileURIs) 
		{
            
			print_desktop(desktopitem);			
			if (uid.to_double()>0)
			{
                DesktopItem		tempdesk;
                string filename;
                try{
                    filename = Filename.from_uri(str);
                }
                catch(ConvertError ex  ){
                    filename="";
                }
                tempdesk = new Awn.DesktopItem(filename);

                if (tempdesk.exists() )
                {
                    if ( !config.multi_launcher || ( desktopitem.get_exec()=="false")) 
                    {
       //                 stdout.printf("drag_data_received 2\n");                        
                        if ( (tempdesk.get_exec() != null) && (tempdesk.get_name()!=null) )
                        {
                            try{
                                tempdesk.save(desktopfile.URI());
                            }catch(GLib.Error ex){
                                stderr.printf("error writing file %s\n",desktopfile.Filename());
                            }
                            
                            desktopitem = new DesktopItem(desktopfile.Filename() );
                            if (desktopitem.get_icon(theme) != null)
                            {
                                icon = new Pixbuf.from_file_at_scale(desktopitem.get_icon(theme),height-2,-1,true );//FIXME - throws
                            }
                            else
                            {
                                icon = theme.load_icon ("stock_stop", height - 2, IconLookupFlags.USE_BUILTIN);
                            }		
                            show_icon();
                            if (config.task_mode != TaskMode.NONE)
                            {
                                books=new BookKeeper();
                            }
                            status=true;
                            books.update_with_desktopitem(desktopitem);
                            SList<string> dummy;
                            dummy.append(desktopfile.Filename());
  //                         stdout.printf("drag_data_received MULTILAUNCHER  1!!!!\n");
                            multi_launcher = new Multi_Launcher(dummy);
//                            multi_launcher.add_file(desktopfile.Filename());
                        }	        
                    }
                    else
                    {
  //                      stdout.printf("drag_data_received 5\n"); 
                        string file_copy;
                        string  desktop_key=desktopitem.get_string("X-AWN-StandaloneLauncherDesktops");

                        if ( desktop_key==null)
                        {
                            desktop_key="";
                        }
                        file_copy=GLib.Path.get_dirname(desktopfile.Filename())+"/"+GLib.Path.get_basename(filename);
                        try{
                            tempdesk.save("file://"+file_copy);
                        }catch(GLib.Error ex){
                            stderr.printf("error writing file %s\n",file_copy);
                        }
                        
                        desktop_key.chomp();
                        if (desktop_key=="")
                        {
                            desktop_key=file_copy;
                        }
                        else
                        {
                            desktop_key=desktop_key+":"+file_copy;
                        }
                        status=true;
                        books.update_with_desktopitem(tempdesk);
//                        stdout.printf("drag_data_received MULTILAUNCHER 2!!!!\n");
                        multi_launcher.add_file(file_copy);
                        desktopitem.set_string("X-AWN-StandaloneLauncherDesktops",desktop_key);
                        try{
                            desktopitem.save("file://"+desktopitem.get_filename());
                        }catch(GLib.Error ex){
                            stderr.printf("error writing file %s\n",desktopfile.Filename());
                        }

                    }
                }
			}		
			print_desktop(desktopitem);						
			Pixbuf temp_icon;
			temp_icon=new Pixbuf.from_file_at_scale( Filename.from_uri(str) ,height-2,height-2,true );
			if (temp_icon !=null)
			{

				icon=temp_icon;
                desktopitem.set_icon(Filename.from_uri(str) );									
				try {
    				desktopitem.save(desktopfile.URI() );				
            	}catch(GLib.Error ex){
            	    stderr.printf("error writing file %s\n",desktopfile.Filename());
            	}
				set_icon(icon);
                show_icon();
				status=true;
			}
		}		
		drag_finish (context, status, false, time);		
    }  

    private Wnck.Window  find_win_by_xid(ulong xid)
    {
		weak	GLib.List	<Wnck.Window>	wins;
		wins=wnck_screen.get_windows();
		foreach (Wnck.Window win in wins)
		{
			if (win.get_xid() == xid)
			{
				return win;
			}		
		}
		return null;
    }

    
    private Wnck.Window  find_win_by_pid(ulong pid)
    {
		weak	GLib.List	<Wnck.Window>	windows;
		windows=wnck_screen.get_windows();
		foreach (Wnck.Window win in windows)
		{
			if (win.get_pid() == pid)
			{
				return win;
			}		
		}
		return null;
    }
    
	private static bool _toggle_win(Wnck.Window win)
	{
	
		return true;
	}
    
    private void button_dialog1()
    {
		if (dialog.visible )
		{
			dialog.hide();
		}
		else
		{
			vbox.destroy();
			vbox = new VButtonBox();
			vbox.set_app_paintable(true);
            dialog.set_app_paintable(false);
			dialog.add(vbox);
			foreach (Wnck.Window win in books.get_wins())
			{
				DiagButton  button = new DiagButton(win,dialog,height);//win.get_name() 				
				vbox.add(button);
			}
			dialog.show_all();
		}		
    }

    private void button_dialog2()
    {
		if (dialog.visible )
		{
			dialog.hide();
		}
		else
		{
			vbox.destroy();
			vbox = new VButtonBox();
			vbox.set_app_paintable(true);
			dialog.set_app_paintable(true);
			dialog.add(vbox);
			foreach (Wnck.Window win in books.get_wins())
			{
				DiagButton  button = new DiagButton(win,dialog,height);//win.get_name() 				
                button.set_app_paintable(true);
				vbox.add(button);
			}
            if (config.multi_launcher) 
            {
			    foreach (weak DesktopItem item in multi_launcher.desktops() )
			    {
                    DesktopitemButton button = new DesktopitemButton(item,dialog,theme,height/2);
                    button.set_app_paintable(true);
                    vbox.add(button);
                }
            }
			dialog.show_all();
		}		
    }

    private void button_dialog(int method)
    {
        switch(method)
        {
            case    1:
                button_dialog1();
                break;
            case    2:
                button_dialog2();
                break;
        }
    }
    
    private bool single_left_click()
    {
		ulong		xid;
		Wnck.Window  win=null;
        uint multi_count=0;
        if (multi_launcher !=null)
        {
            multi_count=multi_launcher.number();
        }

		if ( (books.number()==1) && (multi_count<=2) )
		{	
            int i;
			dialog.hide();
            win=books.get_wins().nth_data(0);
			if (win!=null)
			{
				if (win.is_active() )
				{
					win.minimize();
				}
				else
				{
					win.activate(Gtk.get_current_event_time());
				}
			}
			return (win!=null);			
		}		
		else
		{
			button_dialog(2);
		}
		return true;
    }

    private bool _ungroup_all(Gtk.Widget widget,Gdk.EventButton event)
    {
        weak SList <Wnck.Window> wins=books.get_wins();
        closing=true;
        
        foreach(Wnck.Window win in wins)
        {
            if (books.search_win_by_win(win) != null)
            {
                Return_XID(uid,win.get_xid().to_string());		
            }
        }
        close();
        return false;
    }
    
    private bool _desktop_edit(Gtk.Widget widget,Gdk.EventButton event)
    {
        try{
            Process.spawn_command_line_async(config.desktop_file_editor+" "+desktopfile.Filename() );
        }catch ( SpawnError ex ) {
            stderr.printf("Failed to spawn '%s' \n",config.desktop_file_editor+" "+desktopfile.Filename());
        }
        return false;
    }
  
    private bool _advanced_desktop_edit(Gtk.Widget widget,Gdk.EventButton event)
    {
        try{
            Process.spawn_command_line_async(config.advanced_text_editor+" "+desktopfile.Filename() );
        }catch ( SpawnError ex ) {
            stderr.printf("Failed to spawn '%s' \n",config.advanced_text_editor+" "+desktopfile.Filename());
        }
        return false;
    }  

    private void list_edit(string filename)
    {
        if (!FileUtils.test(filename,FileTest.EXISTS) )
        {
            try{
                FileUtils.set_contents(filename,"#\n#begin with 'TITLE:' or 'EXEC:' followed by regex\n#\n");
            }catch(GLib.FileError ex ){
                stderr.printf("failed creating %s\n",filename);
            }
        }
        try{
            Process.spawn_command_line_async(config.advanced_text_editor+" "+filename );
        }catch ( SpawnError ex ) {
            stderr.printf("Failed to spawn '%s' \n",config.advanced_text_editor+" "+filename);
        }
    }

    private bool _whitelist_edit(Gtk.Widget widget,Gdk.EventButton event)
    {
        list_edit(listing.filename_whitelist_pre());
        return false;
    }

    private bool _blacklist_edit(Gtk.Widget widget,Gdk.EventButton event)
    {
        list_edit(listing.filename_blacklist());
        return false;
    }

    private bool _reread_config(Gtk.Widget widget,Gdk.EventButton event)
    {
        listing = new Listing(GLib.Path.get_basename(desktopfile.Filename()));
        desktopitem = new DesktopItem(desktopfile.Filename() );	
        if (desktopitem.get_icon(theme) != null)
        {
            icon = new Pixbuf.from_file_at_scale(desktopitem.get_icon(theme),height-2,-1,true );
        }
        show_icon();
        return false;
    }

    private void build_right_click()
    {
        Gtk.MenuItem   menu_item;
        right_menu=(Gtk.Menu) create_default_menu();  //FIXME typecast bad.

        menu_item=new MenuItem.with_label ("Ungroup");        
        right_menu.append(menu_item);
        menu_item.show();
        menu_item.button_press_event+=_ungroup_all;

        menu_item=new MenuItem.with_label ("Edit Launcher");        
        right_menu.append(menu_item);
        menu_item.show();
        menu_item.button_press_event+=_desktop_edit;

        menu_item=new MenuItem.with_label ("Advanced Edit Launcher");        
        right_menu.append(menu_item);
        menu_item.show();
        menu_item.button_press_event+=_advanced_desktop_edit;
      
        menu_item=new MenuItem.with_label ("Edit Launcher Whitelist");
        right_menu.append(menu_item);
        menu_item.show();
        menu_item.button_press_event+=_whitelist_edit;

        menu_item=new MenuItem.with_label ("Edit Launcher Blacklist");
        right_menu.append(menu_item);
        menu_item.show();
        menu_item.button_press_event+=_blacklist_edit;

        menu_item=new MenuItem.with_label ("Reread Configuration Files");
        right_menu.append(menu_item);
        menu_item.show();
        menu_item.button_press_event+=_reread_config;
        
    }
    
    private void right_click(Gdk.EventButton event)
    {
        right_menu.popup(null, null, null, event.button, event.time);
    }
    
    private void scroll_active_win(int offset,uint timestamp)
    {
        Wnck.Window win=null;
        Wnck.Window active_win=wnck_screen.get_active_window();
        weak GLib.SList<Wnck.Window> wins=books.get_wins();
        weak GLib.SList<Wnck.Window> result;
        if (active_win == null)
        {
            win=wins.nth_data(0);        
            win.activate(timestamp);
        }
        
        if (active_win !=null)
        {
            result=wins.find(active_win);
            if (result == null)
            {
                win=wins.nth_data(0);
                win.activate(timestamp);
            }
            else
            {
                int position = wins.position(result);
                if ( offset < 0)
                {
                    if (result.next !=null)
                    {
                        result=result.next;
                        weak Wnck.Window win_weak=result.data;
                        win=win_weak;
                    }
                    if(win==null)
                    {
                        win=wins.nth_data(0);
                    }
                }
                else if (offset>0) //UP
                {
                    position--;
                    if (position<0)
                    {
                        position=(int)wins.length();
                        position--;
                    }
                    win=wins.nth_data(position);
                }
                win.activate(timestamp);
            }
        }
        
    }
    
    private void activate_next_win(uint timestamp)
    {
        scroll_active_win(1,timestamp);        
    }
    private void activate_prev_win(uint timestamp)
    {
        scroll_active_win(-1,timestamp);
    }

    private bool _scroll_event(LauncherApplet widget,Gdk.EventScroll event)
    {
        if (  (event.state & Gdk.ModifierType.SHIFT_MASK) != 0)
        {
            activate_prev_win(event.time);
        }
        else
        {
            activate_next_win(event.time);   
        }
        return false;
    }
     
    private bool _button_press(Gtk.Widget widget,Gdk.EventButton event)
    {
		ulong	pid;
		int		xid;

        bool	launch_new=false;
		SList<string>	documents;
        uint multi_count=0;
        
        if (multi_launcher !=null)
        {
            multi_count=multi_launcher.number();
        }
        effects.stop ( Effect.ATTENTION);//effect off
        if (config.task_mode != TaskMode.NONE)  //if it does tasmanagement.
        {
            switch (event.button) 
            {
                case 1:
                    launch_new=true;	        //yes we will launch.
                    if ( (books.number() > 0) || (multi_count>1) )     //already have some XIDs
                    {
                        launch_new=!single_left_click();    //in general will end up false
                    }
                    break;
                case 2:
                    launch_new=true;
                    break;
                case 3:
                    launch_new=false;
                    right_click(event);
                    break;
                default:
                    break;
            }
        }
        else if (event.button==1)
        {
            if (desktopitem.launch(documents) == -1)
            {
                try{
                    Process.spawn_command_line_async(desktopitem.get_exec());
                }catch ( SpawnError ex ) {
                    stderr.printf("failed to spawn '%s'\n",desktopitem.get_exec());
                }
            }
        }
						
		if ( launch_new && (desktopitem!=null) )
		{
      effects.start_ex(Effect.LAUNCHING,null,null,config.max_launch_effect_reps);
			pid=desktopitem.launch(documents);
			if (pid>0)
			{
				stdout.printf("launched: pid = %lu\n",pid);
				books.update_with_pid(pid);
			}
			else if (pid==-1)
			{
                try{
                    Process.spawn_command_line_async(desktopitem.get_exec());
                }catch (  SpawnError ex) {
                    stderr.printf("failed to spawn '%s'\n",desktopitem.get_exec());
                }
			}
		}
		return false;
    }
    
	private void _realized()
	{
        this.window.set_back_pixmap (null,false);
        this.show();
        Timeout.add(200,_initialize);
	}

    private bool _leave_notify(Gtk.Widget widget,Gdk.EventCrossing event)
    {
        title.hide(this );
        return false;   
    }

    
    private bool _enter_notify(Gtk.Widget widget,Gdk.EventCrossing event)
    {
        if (books.number()==0)
        {
            title_string = desktopitem.get_name();
        }
        title.show(this,title_string );
        return false;   
    }
    
	private void _window_closed(Wnck.Screen screen,Wnck.Window window)
	{ 
		dialog.hide();
        if (books.number()==0)
        {
			if (launchmode == LaunchMode.ANONYMOUS)
			{
				Timeout.add(750,_hide_icon);	
                Timeout.add(2000,_hide_icon);	                
				timer_count++;		
				Timeout.add(30000,_timed_closed);
			}	
            else
                show_icon();            
        }
        else if ( config.multi_icon_use && (books.number()==1) )
        {            
            show_icon();
        }
        title_string=desktopitem.get_name();
	}
	
	private bool _timed_closed()
	{
	    timer_count--;
	    if (timer_count <=0)
	    {
        	if (books.number() == 0)
        	{
        		close();
            }     
            else
            {
                hidden=true;
//                stdout.printf("number() = %u\n",books.number() );
            }   		
		}	
		return false;
	}

    private void deal_with_icon(Wnck.Window win)
    {
        Pixbuf new_icon;
        if (config.override_app_icon )
        {
            if ( (desktopitem.get_string("Icon")!=null) && (desktopitem.get_string("Icon")!="none") )
            {
                if (desktopitem.get_icon(theme) != null)
                {
                    new_icon = new Pixbuf.from_file_at_scale(desktopitem.get_icon(theme),height-2,-1,true );//FIXME 
                }
            }
        }
        else if (! win.get_icon_is_fallback() ||  (desktopitem.get_icon(theme) == null) )
        {
            new_icon=win.get_icon();
            new_icon=new_icon.scale_simple (height-2, height-2, Gdk.InterpType.BILINEAR );
        }
        else
        {
            if ( (desktopitem.get_string("Icon")!=null) && (desktopitem.get_string("Icon")!="none") )
            {
                new_icon = new Pixbuf.from_file_at_scale(desktopitem.get_icon(theme),height-2,-1,true );//FIXME - throws
            }
        }
        if (new_icon==null)
        {
            new_icon=win.get_icon();
            new_icon=new_icon.scale_simple (height-2, height-2, Gdk.InterpType.BILINEAR );
        }
        if (new_icon!=null)
        {
            icon=new_icon;
            show_icon();
        }
    }
	
	private bool _try_again()
	{
        int x;
        int y;
        this.window.get_origin(out x,out y);
		foreach( ulong xid in retry_list)
		{
			string response;
			response=Inform_Task_Ownership(uid,xid.to_string(),"ACCEPT");
			if (response=="MANAGE")
			{
                hidden=false;
				Wnck.Window win=find_win_by_xid(xid);
				if (win!=null)          
					books.update_with_win(win);
                else
                    continue;					
                books.update_with_xid(xid);
				retry_list.remove(xid);
				if (launchmode == LaunchMode.ANONYMOUS)
				{
					Wnck.Application app=win.get_application();
					desktopfile.uid = app.get_name();
				}
                deal_with_icon(win);
				win.name_changed+=_win_name_change;
				win.state_changed+=_win_state_change;				
                title_string=win.get_name();     
                win.set_icon_geometry(x,y,height,height);                
			}
			else if (response=="HANDSOFF")
			{
				retry_list.remove(xid);
			}
			else if (response=="RESET")
			{
				Launcher_Register(uid);										
			}		
		}		
		return (retry_list.length() != 0 );
	}
	
	private void _window_opened(Wnck.Screen screen,Wnck.Window window)
	{ 
		string response;
		int pid=window.get_pid();
		ulong xid;
        int x;
        int y;
		bool	accepted=false;		
		xid=window.get_xid();

        if (closing)
            return;
        
        this.window.get_origin(out x,out y);
        foreach (Wnck.Window win in books.get_wins())
        {
            win.set_icon_geometry(x,y,height,height);
        }
		
		if ( (books.number()>0) && (config.task_mode==TaskMode.SINGLE) )
		{
			string response;
			do
			{
			    response=Inform_Task_Ownership(uid,xid.to_string(),"DENY");
                if (response=="RESET")  
					Launcher_Register(uid);													    
            }while(response=="RESET");			    
			return;
		}
        if (window.is_skip_tasklist())
        {
            return;
        }
        else if (books.find_pid(pid) )
        {
            do
            {
                response=Inform_Task_Ownership(uid,xid.to_string(),"CLAIM");            
            }while(response=="RESET");              
        }
        else
        {
            do
            {
                ListingResult listings_check;
                listings_check=listing.check_listings(window.get_name(),get_exec(pid));
                switch (listings_check)
                {
                    case    ListingResult.WHITELISTED:
                        response=Inform_Task_Ownership(uid,xid.to_string(),"CLAIM");
                        break;
                    case    ListingResult.BLACKLISTED:
                        response=Inform_Task_Ownership(uid,xid.to_string(),"DENY");
                        break;
                    case    ListingResult.NOMATCH:
                        {
                            switch (books.what_to_do(window) )
                            {
                                case    Ownership.CLAIM:
                                        response=Inform_Task_Ownership(uid,xid.to_string(),"CLAIM");
                                        break;
                                case    Ownership.ACCEPT:
                                        response=Inform_Task_Ownership(uid,xid.to_string(),"ACCEPT");
                                        break;
                                case    Ownership.DENY:
                                        response=Inform_Task_Ownership(uid,xid.to_string(),"DENY");
                                        break;
                            }
                        }
                        break;
                }
                if (response=="RESET")
                    Launcher_Register(uid);										
            }while(response=="RESET");//this does not eval to true often... otherwise it should be fixed.
        }        
        if(response=="MANAGE")
        {
            hidden=false;
            effects.stop (Effect.LAUNCHING);
            Pixbuf new_icon;
            books.update_with_win(window);			
            deal_with_icon(window);
            title_string=window.get_name();
            window.name_changed+=_win_name_change;
            window.state_changed+=_win_state_change;    
            window.set_icon_geometry(x,y,height,height);
            
 //           stdout.printf("checking for X-AWN-Workspace\n");
            string ws_num_string=desktopitem.get_string("X-AWN-Workspace");            
            if (ws_num_string !=null)
            {
//                stdout.printf("Found X-AWN-Workspace\n");
                window.move_to_workspace( screen.get_workspace(ws_num_string.to_int() ) );
            }
            
        }
        else if (response=="HANDSOFF")
        {

        }
        else if (response=="WAIT")
        {

			retry_list.prepend(xid);
			if (retry_list.length()<2)
			{
				Timeout.add(100,_try_again);
			}		
        }        
	}
    
    private void _win_name_change(Wnck.Window  window)
    {
        title_string=window.get_name();            
    }
    
    private void _win_state_change(Wnck.Window window,Wnck.WindowState changed_mask,Wnck.WindowState new_state)
    {
        if ( ((Wnck.WindowState.DEMANDS_ATTENTION & new_state) == Wnck.WindowState.DEMANDS_ATTENTION) ||
             ((Wnck.WindowState.URGENT & new_state) == Wnck.WindowState.URGENT)
            )
        {
            if (window != wnck_screen.get_active_window ())
            {
                //effect_start_ex(effects, Effect.ATTENTION,null,null,11);    
                effects.start(Effect.ATTENTION);
            }
        }

    }    
    
	private void _application_closed(Wnck.Screen screen,Wnck.Application app)
	{ 
//		PIDs.remove(app.get_pid() );	
	}
	
	private void _application_opened(Wnck.Screen screen,Wnck.Application app)
	{ 
        if (app!=null)
        {
            if (books.find_pid(app.get_pid() ))
            {
                desktopfile.uid = app.get_name();	
                books.update_with_name(app.get_name());
            }
        }
	}

	private void _active_workspace_changed(Wnck.Screen screen,Wnck.Workspace prev)
	{
        if ( (launchmode != LaunchMode.DISCRETE ) && (!config.show_if_on_inactive) )
        {
            Wnck.Workspace active_workspace=screen.get_active_workspace();
            
            hidden=true;
            if (active_workspace !=null)
            {
                weak List<Wnck.Window> wins=screen.get_windows ();
                foreach(weak Wnck.Window win in wins)
                {
                    if (books.find_win(win) )
                    {
                        if ( (win.get_workspace()).get_number()== active_workspace.get_number() )
                        {
                            stdout.printf("active workspace change.  HIDING\n");
                            hidden=false;
                        }
                    }
                } 
                hide_icon();
            }
        }
    }
	private void _active_window_changed(Wnck.Screen screen,Wnck.Window prev)
	{
		Pixbuf  temp;
	    bool    scale_icon=false;
        
        prev = (Wnck.Window) screen;
		Wnck.Window active=wnck_screen.get_active_window();//active can be null
		activated=false;
		if (prev !=null)
		{
    		if (books.find_win(prev))
    		{
    			if (config.override_app_icon )
    			{
                    if ( (desktopitem.get_string("Icon")!=null) && (desktopitem.get_string("Icon")!="none") )
                    {
                        if (desktopitem.get_icon(theme) != null)
                        {				
                            icon = new Pixbuf.from_file_at_scale(desktopitem.get_icon(theme),height-2,-1,true );//FIXME - throws
                        }			
                    }
    			}
    			else if (!prev.get_icon_is_fallback() )
    			{
    				icon=prev.get_icon();
                    scale_icon=true;
    			}		
    			
    		} 			
		}
		if (active !=null)
		{
    		if (books.find_win(active))
    		{
                effects.stop ( Effect.ATTENTION);//effect off
                title_string=active.get_name();
                if (config.override_app_icon )
    			{
                    if ( (desktopitem.get_string("Icon")!=null) && (desktopitem.get_string("Icon")!="none") )
                    {
                        if (desktopitem.get_icon(theme) != null)
                        {
                            icon = new Pixbuf.from_file_at_scale(desktopitem.get_icon(theme),height-2,-1,true );//FIXME - throws
                        }
                        else if (!active.get_icon_is_fallback() )
                        {
                            icon=active.get_icon();
                            scale_icon=true;
                        }
                    }
                    else if (!active.get_icon_is_fallback() )
    				{
    					icon=active.get_icon();
                        scale_icon=true;
    				}
    			}
    			else if (!active.get_icon_is_fallback() )
    			{
    				icon=active.get_icon();
                    scale_icon=true;    				    		
                }            
                activated=true;
    		}
        }    		
        if (scale_icon)
        {
            icon=icon.scale_simple (height-2, height-2, Gdk.InterpType.BILINEAR );		
        }
        show_icon();		
	}
}
 
public Applet awn_applet_factory_initp (string uid, int orient, int height) 
{
	LauncherApplet applet;
	Wnck.set_client_type (Wnck.ClientType.PAGER);
	applet = new LauncherApplet (uid, orient, height);
	applet.set_size_request (height, -1);
	applet.show_all ();
	return applet;
}

/* vim: set ft=cs noet ts=4 sts=4 sw=4 : */
