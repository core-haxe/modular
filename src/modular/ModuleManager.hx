package modular;

#if !modular_host

import promises.Promise;

extern class ModuleManager {
    public var basePath:String;
    public var subDirectory:String;

    public static var instance(get, null):ModuleManager;

    public function addStartUpModule(name:String, callback:Module->Void = null):Void;
    public function find(name:String):Module;
    public function get(name:String, type:String = null):Promise<Module>;
    public function createClassInstance<T>(name:String, type:Class<T> = null):Promise<T>;
    public function createLoadedClassInstance<T>(name:String, type:Class<T> = null):T;
}

#else

import haxe.io.Path;
import logging.Logger;
import promises.Promise;
import promises.PromiseUtils;

using StringTools;

@:expose
class ModuleManager {
    private var log = new Logger(ModuleManager);

    private static var _instance:ModuleManager = null;
    public static var instance(get, null):ModuleManager;
    private static function get_instance():ModuleManager {
        if (_instance == null) {
            _instance = new ModuleManager();
        }
        return _instance;
    }

    private function new() {
    }

    public var basePath:String = null;
    public var subDirectory:String = "modules";
    public var moduleSuffix:String = null;

    private var _startUpModules:Array<StartUpModuleEntry> = [];
    public function addStartUpModule(name:String, callback:Module->Void = null) {
        _startUpModules.push({
            name: name,
            callback: callback
        });
    }

    private function findStartUpEntryCallback(name:String):Module->Void {
        for (entry in _startUpModules) {
            if (entry.name == name) {
                return entry.callback;
            }
        }
        return null;
    }

    private var _init:Bool = false;
    public function init():Promise<Bool> {
        return new Promise((resolve, reject) -> {
            if (_init) {
                resolve(true);
            } else {
                var list = [];
                for (entry in _startUpModules) {
                    list.push(get.bind(entry.name));
                }
                PromiseUtils.runAll(list).then(_ -> {
                    _init = true;
                    resolve(true);
                }, error -> {
                    reject(error);
                });
            }
        });
    }

    public function find(name:String):Module {
        return _loadedModules.get(name);
    }

    private var _loadedModules:Map<String, Module> = [];
    private var _loadingModules:Map<String, Array<{resolve:Module->Void, reject:Dynamic->Void}>> = [];
    public function get(name:String, type:String = null):Promise<Module> {
        return new Promise((resolve, reject) -> {
            log.info('attempting to load module "${name} (${type})"');
            if (_loadedModules.exists(name)) {
                log.info('module "${name}" in found in cache, reusing');
                resolve(_loadedModules.get(name));
            } else {
                /*
                // modules/myModule/myModule.js|.cppia
                var filename = name;
                if (name.indexOf("/") != -1) {
                    filename = name.split("/").pop();
                }
                */

                // modules/myModule.js|.cppia
                var basePath = this.basePath;
                if (basePath == null) {
                    basePath = "";
                } else if (!basePath.endsWith("/")) {
                    basePath += "/";
                }
                var path = Path.normalize(basePath + subDirectory + "/" + name);

                if (_loadingModules.exists(path)) {
                    log.info('module "${name}" already loading, deferring');
                    var list = _loadingModules.get(path);
                    if (list == null) {
                        list = [];
                        _loadingModules.set(path, list);
                    }
                    list.push({resolve: resolve, reject: reject});
                    return;
                }

                var list = _loadingModules.get(path);
                if (list == null) {
                    list = [];
                    _loadingModules.set(path, list);
                }
                list.push({resolve: resolve, reject: reject});

                
                var loader = new ModuleLoader();
                loader.suffix = this.moduleSuffix;
                loader.load(path).then(loader -> {
                    var module = new Module();
                    @:privateAccess module._loader = loader;
                    if (type == null || type == "") {
                        var namespace = name.split("/").pop();
                        @:privateAccess module.init(namespace);
                    }

                    var dependencyPromises = [];
                    if (module.descriptor != null && module.descriptor.dependencies != null) {
                        for (dependency in module.descriptor.dependencies) {
                            dependencyPromises.push(get.bind(dependency.path, dependency.type));
                        }
                    }

                    PromiseUtils.runSequentially(dependencyPromises).then(_ -> {
                        var callback = findStartUpEntryCallback(name);
                        if (callback != null) {
                            callback(module);
                        }

                        //resolve(module);
                        var list = _loadingModules.get(path);
                        if (list != null) {
                            while (list.length > 0) {
                                list.shift().resolve(module);
                            }
                        }
                        _loadedModules.set(name, module);
                    }, error -> {
                        reject(error);
                    });
                }, error -> {
                    trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ERROR", error);
                    var list = _loadingModules.get(path);
                    if (list != null) {
                        while (list.length > 0) {
                            list.shift().reject(error);
                        }
                    }
                    //reject(error);
                });
            }
        });
    }

    public function createClassInstance<T>(name:String, type:Class<T> = null):Promise<T> {
        return new Promise((resolve, reject) -> {
            var nameParts = name.split("/");
            var className = nameParts.pop();
            var moduleName = nameParts.join("/");
            get(moduleName).then(module -> {
                var classInstance = module.createClassInstance(className, type);
                resolve(classInstance);
            }, error -> {
                reject(error);
            });
        });
    }

    public function createLoadedClassInstance<T>(name:String, type:Class<T> = null):T {
        var nameParts = name.split("/");
        var className = nameParts.pop();
        var moduleName = nameParts.join("/");
        return find(moduleName).createClassInstance(className, type);
    }
}

private typedef StartUpModuleEntry = {
    var name:String;
    @:options var callback:Module->Void;
}

#end