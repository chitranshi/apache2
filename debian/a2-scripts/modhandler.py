#!/usr/bin/env python
# Copyright (C) Thom May 2002
#All rights reserved.

#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions
#are met:
#1. Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#2. Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.

#THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
#IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
#OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
#INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
#NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
#THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#TODO: add --force option

import shelve, textwrap

__all__ = ["ModHandler", "ModHandlerException", "ModuleAlreadyExists", "NoSuchModule"]

class ModHandlerException(Exception):
    pass

class ModuleAlreadyExists(ModHandlerException):
    def __init__(self, name):
        self.args = name
        self.name = name
        
class NoSuchModule(ModHandlerException):
    def __init__(self, name):
        self.args = name
        self.name = name

class ModHandler:
    def __init__(self, db):
        self.registry = shelve.open(db,"c",writeback=True)
        self.revision = "$LastChangedRevision: 19 $"
        
    def add(self,module,sequence=99,*dependencies):
        """add(module[, sequence, *dependencies])
    
        Add a module into the registry ready for enabling.
        module is the name of the module
        sequence is the sequence number of the module. The default is 99
        any further arguments define dependencies for the module"""
    
        if __debug__: print "The module is", module, "and the sequence number is",sequence,"\n"
        state = "disabled"
        #now we create a tuple
        # name, sequence, state, [dependencies]
        if len(dependencies) > 0:
            entry = module, sequence, state, 0, dependencies
        else:
            entry = module, sequence, state, 0
        
        if self.registry.has_key(module):
            raise ModuleAlreadyExists(module)
            
        self.registry[module] = entry
        return 0
        
    def dolist(self):
        """dolist (no arguments) 
        lists all the current elements in the database."""
    
        for key in self.registry.keys():
             print textwrap.fill("The name of the key is %s and the data in the key is: %s" % (key , self.registry[key][:3])) 
             if len(self.registry[key]) > 4:
                print textwrap.fill("The dependencies for %s are: %s\n" % (key ,  self.registry[key][4]))
             if self.registry[key][3] > 0:
                 print textwrap.fill("%s is in use %s times\n" % (key, self.registry[key][3]))
             print 
        
    def remove(self,module):
        if __debug__: print "Plotting to remove",module,"\n"
        try:        
            self.disable(module)
            del self.registry[module]
            if __debug__: print "Removed",module
        except KeyError:
            raise NoSuchModule(module)
        return 0
        
    def enable(self,module,isdependency=False,*dependseq):
        """enable(module,[dependseq])
        
        enable takes one or two arguments. in normal opperation, just the module 
        name is passed. When being run recursively to fix dependencies, the
        dependency sequence of the depending module is also passed"""
        
        try:
             data = self.registry[module]
        except KeyError:
            raise NoSuchModule(module)
        
        #now, we check to see if our sequence number is higher than the module that's depending on us
        #if so, we bump our sequence number down to one less than the depending module
        changedseqnum = True
        seqnum = data[1]
        if __debug__: print module+": seqnum "+str(seqnum)
        if len(dependseq) > 0:
             if __debug__: print module+": dependseq "+str(dependseq[0])
             if int(seqnum) > int(dependseq[0]):
                oldseqnum = seqnum
                seqnum = int(dependseq[0])
                seqnum = seqnum - 1
                if __debug__:
                    print module +": punting old seqnum:",str(oldseqnum)," to new seqnum:",str(seqnum)
                    print "new seqnum:",str(seqnum)
                #changedseqnum = True
             else:
                changedseqnum = False
         
        #next, we need to load any dependencies.
        #this is complicated by the need to get the sequence right.
        if len(data) > 4:
             dependencies = data[4]
             if __debug__: print dependencies
             for dependency in dependencies:
                  if __debug__: print dependency
                  returncode = self.enable(dependency,True,seqnum)
                  if __debug__: print returncode
                  
        #now, we check whether the module is loaded already
        if data[2] == "enabled" and changedseqnum == False:
              #nothing more to do.
              return
        else:
              self.switchon(module,seqnum)

        refcount = data[3]
        if isdependency:
            refcount += 1
        
        #ok, nothing has broken. Only now do we update the module's status.
        #it would be nice to provide some semblance of atomicity to the 
        #operation
        if len(data) < 5:
            newstatus = module, seqnum, "enabled", refcount
        else:
            newstatus = module, seqnum, "enabled", refcount, dependencies
        
        self.registry[module] = newstatus
        
    def disable(self,module):
        """disable(module) marks a module as disabled"""
    
        #this might require some form of refcounting so we can work out if any 
        #unneeded dependencies can be unloaded as well, for example with mod_dav         
        #and its providers, such as dav_fs or dav_svn - but not till the basic
        #functionality works ;-)
        
        
        try:
            data = self.registry[module]
        except KeyError:
            raise NoSuchModule(module)
        if data[2] == "disabled":
            return

        if __debug__: print "shutting",module,"down\n"
        
        #try:
        self.switchoff(module,data[1])
        
        if len(data) < 4:
            newstatus = module, data[1], "disabled"
        else:
             newstatus = module, data[1], "disabled", data[3]
        
        self.registry[module] = newstatus
        
    def version(self, versionnum):
        
        print "The version of the client is",versionnum
        print "The revision number of ModHandler is %s" % self.revision.strip('$').split(':')[1].strip() 
        
    def switchon(self,module,seqnum): pass
        
    def switchoff(self,module): pass
