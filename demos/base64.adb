------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                            Copyright (C) 2000                            --
--                               Pascal Obry                                --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.          --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

--  $Id$

with Ada.Text_IO;
with Ada.Streams.Stream_IO;

with AWS.Translater;

procedure Base64 is

   use Ada;

   File   : Streams.Stream_IO.File_Type;
   Buffer : Streams.Stream_Element_Array (1 .. 10_000);
   Last   : Streams.Stream_Element_Offset;

begin

   Text_IO.Put_Line
     ('[' & AWS.Translater.Base64_Encode ("Aladdin:open sesame") & ']');

   Streams.Stream_IO.Open (File, Streams.Stream_IO.In_File, "adains.gif");
   Streams.Stream_IO.Read (File, Buffer, Last);
   Streams.Stream_IO.Close (File);

   Streams.Stream_IO.Create (File,
                             Streams.Stream_IO.Out_File, "adains_dec.gif");

   declare
      S : constant String := AWS.Translater.Base64_Encode (Buffer (1 .. Last));
   begin
      Text_IO.Put_Line (S);
      Streams.Stream_IO.Write (File, AWS.Translater.Base64_Decode (S));
   end;

   Streams.Stream_IO.Close (File);
end Base64;
