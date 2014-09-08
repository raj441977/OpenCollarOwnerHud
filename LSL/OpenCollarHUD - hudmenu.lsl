////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenCollarHUD - hudmenu                             //
//                                 version 3.945                                  //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.  ->  www.opencollar.at/license.html  //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2014  Individual Contributors and OpenCollar - submission set free™ //
// ------------------------------------------------------------------------------ //
////////////////////////////////////////////////////////////////////////////////////

//on start, send request for submenu names
//on getting submenu name, add to list if not already present
//on menu request, give dialog, with alphabetized list of submenus
//on listen, send submenu link message

list localcmds = ["menu"];
list menunames = ["Main"];

//  exists in parallel to menunames, each entry containing a pipe-delimited string with the items for the corresponding menu
list menulists = [""];

//MESSAGE MAP
integer COMMAND_OWNER     = 500;

integer COMMAND_UPDATE    = 10001;

integer MENUNAME_RESPONSE = 3001;
integer SUBMENU           = 3002;
integer MENUNAME_REMOVE   = 3003;
integer DIALOG            = -9000;
integer DIALOG_RESPONSE   = -9001;
integer DIALOG_TIMEOUT    = -9002;

integer SEND_CMD_PICK_SUB = -1002;

integer LOCALCMD_REQUEST  = -2000;
integer LOCALCMD_RESPONSE = -2001;

string UPMENU = "Back";

key wearer;
key menuid;

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page)
{
    key id = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page +
        "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);
    return id;
}

Menu(string name, key id)
{
    integer menuindex = llListFindList(menunames, [name]);

    if (menuindex == -1) return;

//  this should be multipage in case there are more than 12 submenus, but for now single page
//  get submenu

    list buttons = llParseString2List(llList2String(menulists, menuindex), ["|"], []);
    list utility = [];
    string prompt = "Pick an option.";
    menuid = Dialog(id, prompt, buttons, utility, 0);
}

default
{
    state_entry()
    {
        wearer = llGetOwner();
        llSleep(1.0);//delay sending this message until we're fairly sure that other scripts have reset too, just in case
        //need to populate main menu with buttons for all menus we provide other than "Main"
        integer stop = llGetListLength(menunames);

        integer n;
        for (; n < stop; n++)
        {
            string name = llList2String(menunames, n);
            if (name != "Main")
            {
                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, "Main|" + name, "");
                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, name + "|" + UPMENU, "");
            }
        }
        //add "CollarMenu", and RLVMenu buttons to main menu
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, "Main|CollarMenu", "");
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, "Main|UnDressMenu", "");
    }

    touch_start(integer num)
    {
        key id = llDetectedKey(0);

        if ((llGetAttached() == 0)&& (id==wearer)) // Dont do anything if not attached to the HUD
        {
            llMessageLinked(LINK_THIS, COMMAND_UPDATE, "Update", id);
            return;
        }

        if (id == wearer)
        {
//          I made the root prim the "menu" prim, and the button action default to "menu."

            string button = (string)llGetObjectDetails(llGetLinkKey(llDetectedLinkNumber(0)),[OBJECT_DESC]);


            if (button == "TPSubs")
                llMessageLinked(LINK_SET, COMMAND_OWNER,"TPMenus", id);
            else if (button == "Menu")
                Menu("Main", id);
            else if (button == "Cage")
                llMessageLinked(LINK_SET, COMMAND_OWNER,"cagemenu","");
            else if (button == "Couples")
                llMessageLinked(LINK_THIS, SEND_CMD_PICK_SUB, "couples", "");
            else if (button == "Leash")
                llMessageLinked(LINK_SET, COMMAND_OWNER,"LeashMenus", id);
            else if (llSubStringIndex(button,"Owner")>=0)
            {
                llMessageLinked(LINK_SET, COMMAND_OWNER,"hide","");
                llSleep(1);
            }
            else
                llMessageLinked(LINK_SET, COMMAND_OWNER,button, id);
        }
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == MENUNAME_RESPONSE)
        {
//          str will be in form of "parent|menuname"
//          ignore unless parent is in our list of menu names

            list params = llParseString2List(str, ["|"], []);
            integer menuindex = llListFindList(menunames, llList2List(params, 0, 0));
            if (~menuindex)
            {
                string submenu = llList2String(params, 1);

//              only add submenu if not already present
                list guts = llParseString2List(llList2String(menulists, menuindex), ["|"], []);

                if (~llListFindList(guts, [submenu])) return;

                guts += [submenu];
                guts = llListSort(guts, 1, TRUE);
                menulists = llListReplaceList(menulists, [llDumpList2String(guts, "|")], menuindex, menuindex);
            }
        }
        else if (num == MENUNAME_REMOVE)
        {
//          str should be in form of parentmenu|childmenu

            list    params    = llParseString2List(str, ["|"], []);
            string  parent    = llList2String(params, 0);
            string  child     = llList2String(params, 1);
            integer menuindex = llListFindList(menunames, [parent]);

            if (menuindex == -1) return;

            list    guts     = llParseString2List(llList2String(menulists, menuindex), ["|"], []);
            integer gutindex = llListFindList(guts, [child]);

//          only remove if it's there
            if (gutindex == -1) return;

            guts = llDeleteSubList(guts, gutindex, gutindex);
            menulists = llListReplaceList(menulists, [llDumpList2String(guts, "|")], menuindex, menuindex);
        }
        else if (num == SUBMENU)
        {
            if (llListFindList(menunames, [str]) != -1)
                Menu(str, id);
//          lets bring up the special collar menu's
            else if (str == "CollarMenu")
                llMessageLinked(LINK_THIS, SEND_CMD_PICK_SUB, "menu", "");
            else if (str == "UnDressMenu")
                llMessageLinked(LINK_THIS, SEND_CMD_PICK_SUB, "undress", "");
        }
        else if (num == COMMAND_OWNER)
        {
            if (str == "menu")
                Menu("Main", id);
        }
        else if (num == LOCALCMD_REQUEST)
            llMessageLinked(LINK_THIS, LOCALCMD_RESPONSE, llDumpList2String(localcmds, ","), "");
        else if (num == DIALOG_RESPONSE)
        {
            if(id == menuid)
            {
                list menuparams = llParseString2List(str, ["|"], []);
                id = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);

                if (message == UPMENU)
                    Menu("Main", llGetOwner());
                else
                    llMessageLinked(LINK_SET, SUBMENU, message, llGetOwner());
            }
        }
        else if (num == DIALOG_TIMEOUT)
        {
            if(id == menuid)
                llOwnerSay("Main Menu timed out!");
        }

    }

    changed(integer change)
    {
        if (change & CHANGED_OWNER)
            llResetScript();
    }
}
