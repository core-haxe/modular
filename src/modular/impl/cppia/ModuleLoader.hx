package modular.impl.cppia;

import logging.Logger;
import sys.io.File;
import haxe.io.Path;
import promises.Promise;
import cpp.cppia.Module as NativeModule;

using StringTools;

class ModuleLoader extends ModuleLoaderBase {
    private var log = new Logger(ModuleLoader);

    private var nativeModule:Dynamic = null; // cant type this as hxcpp complains

    public override function load(name:String):Promise<modular.ModuleLoader> {
        return new Promise((resolve, reject) -> {
            var filename = Path.normalize(name);
            if (!StringTools.startsWith(filename, "./")) {
                filename = "./" + filename;
            }
            if (!StringTools.endsWith(filename, ".cppia")) {
                filename += ".cppia";
            }
    
            log.info('loading cppia module "${filename}"');
            var bytes = File.getBytes(filename);
            var nativeModule = NativeModule.fromData(bytes.getData());
            nativeModule.boot();
            this.nativeModule = nativeModule;
            log.info('loaded cppia module "${filename}"');

            resolve(this);
        });
    }

    public override function createClassInstance<T>(name:String, type:Class<T> = null):T {
        var nativeModule:NativeModule = cast this.nativeModule;
        var cls = nativeModule.resolveClass(name);
        trace(cls, Type.getSuperClass(cls));

        if (type == null) {
            var inst:Dynamic = Type.createInstance(cls, []);
            return inst;
        }

        var inst:T = Type.createInstance(cls, []);
        return inst;
    }
    
}