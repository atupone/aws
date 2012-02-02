------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2000-2012, AdaCore                     --
--                                                                          --
--  This is free software;  you can redistribute it  and/or modify it       --
--  under terms of the  GNU General Public License as published  by the     --
--  Free Software  Foundation;  either version 3,  or (at your option) any  --
--  later version.  This software is distributed in the hope  that it will  --
--  be useful, but WITHOUT ANY WARRANTY;  without even the implied warranty --
--  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU     --
--  General Public License for  more details.                               --
--                                                                          --
--  You should have  received  a copy of the GNU General  Public  License   --
--  distributed  with  this  software;   see  file COPYING3.  If not, go    --
--  to http://www.gnu.org/licenses for a complete copy of the license.      --
------------------------------------------------------------------------------

with Ada.Text_IO;
with Ada.Exceptions;

with GNAT.MD5;

with AWS.Client;
with AWS.Digest;
with AWS.Server.Status;
with AWS.Status;
with AWS.MIME;
with AWS.Response;
with AWS.Messages;
with AWS.Utils;

with Get_Free_Port;
with Stack_Size;

procedure Auth1 is

   use GNAT;
   use Ada;
   use Ada.Text_IO;
   use AWS;

   function CB (Request : Status.Data) return Response.Data;

   task Server is
      pragma Storage_Size (Stack_Size.Value);
      entry Wait_Start;
      entry Stop;
   end Server;

   HTTP : AWS.Server.HTTP;

   Connect : Client.HTTP_Connection;

   Basic_Protected_URI  : constant String := "/Basic";
   Digest_Protected_URI : constant String := "/Digest";
   Any_Protected_URI    : constant String := "/Any";

   Auth_Username : constant String := "AWS";
   Auth_Password : constant String := "letmein";

   R    : Response.Data;
   Port : Natural := 1236;

   --------
   -- CB --
   --------

   function CB (Request : Status.Data) return Response.Data is
      Username    : String := AWS.Status.Authorization_Name (Request);
      Valid_Nonce : Boolean;
   begin
      if Status.URI (Request) = Basic_Protected_URI then

         if Username = Auth_Username
           and then AWS.Status.Authorization_Password (Request) = Auth_Password
         then
            return AWS.Response.Build
              ("text/plain", "Basic authorization OK!");
         else
            return AWS.Response.Authenticate
              ("AWS regtest", AWS.Response.Basic);
         end if;

      elsif Status.URI (Request) = Digest_Protected_URI then
         Valid_Nonce
           := Digest.Check_Nonce (Status.Authorization_Nonce (Request));

         if AWS.Status.Authorization_Response (Request)
            = MD5.Digest
                (MD5.Digest
                   (Username
                    & ':' & AWS.Status.Authorization_Realm (Request)
                    & ':' & Auth_Password)
                 & AWS.Status.Authorization_Tail (Request))
           and then Valid_Nonce
         then
            return AWS.Response.Build
              ("text/plain", "Digest authorization OK!");
         else
            return AWS.Response.Authenticate
              ("AWS regtest", AWS.Response.Digest, Stale => not Valid_Nonce);
         end if;

      elsif Status.URI (Request) = Any_Protected_URI then
         Valid_Nonce
           := Digest.Check_Nonce (Status.Authorization_Nonce (Request));

         if AWS.Status.Check_Digest (Request, Auth_Password)
           and then Valid_Nonce
         then
            return AWS.Response.Build
              ("text/plain", "AWS strongest authorization OK!");
         else
            return AWS.Response.Authenticate
              ("AWS regtest", AWS.Response.Any, Stale => not Valid_Nonce);
         end if;

      else
         return AWS.Response.Build
           ("text/plain", "No authentication.");
      end if;
   end CB;

   ------------
   -- Server --
   ------------

   task body Server is
   begin
      Get_Free_Port (Port);

      AWS.Server.Start
        (HTTP, "Test authentication.",
         CB'Unrestricted_Access, Port => Port, Max_Connection => 3);

      accept Wait_Start;
      accept Stop;

   exception
      when E : others =>
         Put_Line ("Server Error " & Exceptions.Exception_Information (E));
   end Server;

begin
   Server.Wait_Start;

   Client.Create
     (Connection => Connect,
      Host       => "http://" & AWS.Server.Status.Host (HTTP) & ':'
                      & Utils.Image (Port),
      Timeouts   => Client.Timeouts
        (Connect => 5.0, Send => 5.0, Receive => 5.0));

   --  Test for basic authentication

   Client.Set_WWW_Authentication
     (Connect, Auth_Username, "Wrong_Password", Client.Basic);

   Client.Get (Connect, R, "/Basic?param=value");
   Put_Line ("-> " & Messages.Image (Response.Status_Code (R)));

   Client.Set_WWW_Authentication
     (Connect, Auth_Username, Auth_Password, Client.Basic);

   Client.Get (Connect, R, "/Basic?param=value");
   Put_Line ("-> " & Messages.Image (Response.Status_Code (R)));
   Put_Line ("-> " & Response.Message_Body (R));

   --  Test for digest authentication

   Client.Set_WWW_Authentication
     (Connect, Auth_Username, "Wrong_Password", Client.Digest);

   Client.Get (Connect, R, "/Digest?param=value");
   Put_Line ("-> " & Messages.Image (Response.Status_Code (R)));

   Client.Set_WWW_Authentication
     (Connect, Auth_Username, Auth_Password, Client.Digest);

   Client.Get (Connect, R, "/Digest?param=value");
   Put_Line ("-> " & Messages.Image (Response.Status_Code (R)));
   Put_Line ("-> " & Response.Message_Body (R));

   --  Test for strongest authentication

   Client.Set_WWW_Authentication
     (Connect, Auth_Username, "Wrong_Password", Client.Any);

   Client.Get (Connect, R, "/Any?param=value");
   Put_Line ("-> " & Messages.Image (Response.Status_Code (R)));

   Client.Set_WWW_Authentication
     (Connect, Auth_Username, Auth_Password, Client.Any);

   Client.Get (Connect, R, "/Any?param=value");
   Put_Line ("-> " & Messages.Image (Response.Status_Code (R)));
   Put_Line ("-> " & Response.Message_Body (R));

   Client.Close (Connect);

   Server.Stop;

exception
   when E : others =>
      Server.Stop;
      Put_Line ("Main Error " & Exceptions.Exception_Information (E));
end Auth1;
