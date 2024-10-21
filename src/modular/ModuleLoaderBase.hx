package modular;

#if modular_host

import promises.Promise;

class ModuleLoaderBase {
    public function new() {
    }

    public function load(name:String):Promise<modular.ModuleLoader> {
        return new Promise((resolve, reject) -> {
            reject("not implemented");
        });
    }

    public function createClassInstance<T>(name:String, type:Class<T> = null):T {
        return null;
    }
}

#end