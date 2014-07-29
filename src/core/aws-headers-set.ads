------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2000-2014, AdaCore                     --
--                                                                          --
--  This library is free software;  you can redistribute it and/or modify   --
--  it under terms of the  GNU General Public License  as published by the  --
--  Free Software  Foundation;  either version 3,  or (at your  option) any --
--  later version. This library is distributed in the hope that it will be  --
--  useful, but WITHOUT ANY WARRANTY;  without even the implied warranty of --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                    --
--                                                                          --
--  As a special exception under Section 7 of GPL version 3, you are        --
--  granted additional permissions described in the GCC Runtime Library     --
--  Exception, version 3.1, as published by the Free Software Foundation.   --
--                                                                          --
--  You should have received a copy of the GNU General Public License and   --
--  a copy of the GCC Runtime Library Exception along with this program;    --
--  see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see   --
--  <http://www.gnu.org/licenses/>.                                         --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

pragma Ada_2012;

package AWS.Headers.Set is

   Format_Error : exception renames Headers.Format_Error;

   procedure Add (Headers : in out List; Name, Value : String) with
     Inline => True,
     Post   => Count (Headers) = Count (Headers'Old) + 1;
   --  Add HTTP header name/value at the end of the Headers container. Note
   --  that there is no check about validity of this header. This service is
   --  provided to be able to create user-defined headers.

   procedure Update
     (Headers : in out List;
      Name    : String;
      Value   : String;
      N       : Positive := 1)
   with
     Inline => True,
     Pre    =>
       --  Count + 1 means it is added at the end of the table
       N <= Count (Headers, Name) + 1,
     Post   =>
       --  Value already exists, it is updated
       (N <= Count (Headers'Old, Name)
        and then Count (Headers, Name) = Count  (Headers'Old, Name))
       --  New value appended
       or else
         (N = Count (Headers'Old, Name) + 1
          and then N = Count (Headers, Name));
   --  Update the N-th HTTP header Value with the given Name.
   --  The header could already have more than one value associated with
   --  this name.

   procedure Read (Socket : Net.Socket_Type'Class; Headers : in out List);
   --  Read and parse HTTP header from the socket

   procedure Reset (Headers : in out List) with
     Inline => True,
     Post   => Count (Headers) = 0;
   --  Removes all object from Headers. Headers will be reinitialized and will
   --  be ready for new use.

   procedure Debug (Activate : Boolean);
   --  Turn on Debug output

end AWS.Headers.Set;
