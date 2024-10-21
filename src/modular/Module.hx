package modular;

#if !modular_host

extern class Module {
    public function createClassInstance<T>(name:String, type:Class<T> = null):T;
}

#else

import haxe.crypto.Base64;
import haxe.io.Bytes;
import promises.Promise;

using StringTools;

class Module {
    private var _loader:ModuleLoader;
    private var singletonInstances:Map<String, Dynamic> = [];

    public var descriptor:IModuleDescriptor;

    public function new() {
    }

    private function init(namespace:String) {
        var moduleDescriptorClass = "ModuleDescriptor";
        if (namespace != null && namespace.trim().length > 0) {
            moduleDescriptorClass = namespace + "." + moduleDescriptorClass;
        }

        var moduleDescriptor = createClassInstance(moduleDescriptorClass, IModuleDescriptor);
        if (moduleDescriptor != null) {
            this.descriptor = moduleDescriptor;

            // this feels naughty :) 
            if (moduleDescriptor.resources != null) {
                var currentModuleResourceNames = haxe.Resource.listNames();
                for (resource in moduleDescriptor.resources) {
                    if (!currentModuleResourceNames.contains(resource.name)) {
                        @:privateAccess haxe.Resource.content.push(resource);
                    }
                }
            }

            #if nodejs
            // when loading a module, the __interfaces__ haxe construct doesnt come through correctly,
            // this means things like "(someClass is ISomeInterface)" always returns false since internally
            // that checks this __interfaces__ member var, we'll recreate that.
            if (moduleDescriptor.classes != null) {
                for (moduleClass in moduleDescriptor.classes) {
                    if (moduleClass.interfaces != null) {
                        for (moduleClassInterface in moduleClass.interfaces) {
                            var nameParts = moduleClass.name.split(".");
                            var ref = @:privateAccess _loader.module;
                            while (ref != null && nameParts.length != 0) {
                                var namePart = nameParts.shift();
                                ref = js.Syntax.code("{0}[{1}]", ref, namePart);
                            }

                            if (ref != null) {
                                var __interfaces__:Array<Dynamic> = Reflect.field(ref, "__interfaces__");
                                if (__interfaces__ == null) {
                                    __interfaces__ == [];
                                    Reflect.setField(ref, "__interfaces__", __interfaces__);
                                }

                                var interfaceNameParts = moduleClassInterface.split(".");
                                var interfaceRef = js.Syntax.code("global");
                                while (interfaceRef != null && interfaceNameParts.length != 0) {
                                    var interfaceNamePart = interfaceNameParts.shift();
                                    interfaceRef = js.Syntax.code("{0}[{1}]", interfaceRef, interfaceNamePart);
                                }
                                if (interfaceRef != null) {
                                    __interfaces__.push(interfaceRef);
                                }
                            }
                        }
                    }
                }
            }

            #elseif js

            if (moduleDescriptor.wireModule != null) {
                moduleDescriptor.wireModule({
                    resolveClass: Type.resolveClass,
                    resolveEnum: Type.resolveEnum
                });
            }

            if (moduleDescriptor.classes != null) {
                for (moduleClass in moduleDescriptor.classes) {
                    var nameParts = moduleClass.name.split(".");
                    var ref = js.Syntax.code("window");
                    while (ref != null && nameParts.length != 0) {
                        var namePart = nameParts.shift();
                        ref = js.Syntax.code("{0}[{1}]", ref, namePart);
                    }
                    if (ref != null) {
                        js.Syntax.code("if (!$hxClasses[{0}]) $hxClasses[{0}] = {1}", moduleClass.name, ref);
                    }
                }
            }
            #end

            if (moduleDescriptor.init != null) {
                moduleDescriptor.init();
            }
        }
    }

    private function findClassDescriptor(name:String):ModuleClassDescriptor {
        if (descriptor == null) {
            return null;
        }
        if (descriptor.classes == null) {
            return null;
        }

        for (classInfo in descriptor.classes) {
            if (classInfo.name == name) {
                return classInfo;
            }
        }
        return null;
    }

    public function listResourceNames():Array<String> {
        if (descriptor == null) {
            return [];
        }

        if (descriptor.resources == null) {
            return [];
        }

        var names = [];
        for (resource in descriptor.resources) {
            names.push(resource.name);
        }
        return names;
    }

    public function getResourceString(name:String):String {
        if (descriptor == null) {
            return null;
        }

        if (descriptor.resources == null) {
            return null;
        }

        for (resource in descriptor.resources) {
            if (resource.name == name) {
                return resource.data;
            }
        }

        return null;

    }

    public function getResourceBytes(name:String):Bytes {
        if (descriptor == null) {
            return null;
        }

        if (descriptor.resources == null) {
            return null;
        }

        for (resource in descriptor.resources) {
            if (resource.name == name) {
                return Base64.decode(resource.data);
            }
        }

        return null;

    }

    public function createClassInstance<T>(name:String, type:Class<T> = null):T {
        var isSingleton = false;
        var classInfo = findClassDescriptor(name);
        if (classInfo != null && classInfo.singleton) {
            isSingleton = classInfo.singleton;
        }
        
        var instance:T = null;
        if (isSingleton) {
            if (singletonInstances.exists(name)) {
                instance = singletonInstances.get(name);
            } else {
                instance = _loader.createClassInstance(name, type);    
                singletonInstances.set(name, instance);
            }
        } else {
            instance = _loader.createClassInstance(name, type);
        }

        return instance;
    }

    public function findClassesByInterface<T>(type:Class<T>):Array<String> {
        var classes = [];
        if (descriptor != null && descriptor.classes != null) {
            var typeString = Type.getClassName(type);
            for (cls in descriptor.classes) {
                if (cls.interfaces != null) {
                    for (i in cls.interfaces) {
                        if (i == typeString) {
                            classes.push(cls.name);
                            break;
                        }
                    }
                }
            }
        }
        return classes;
    }
}

#end