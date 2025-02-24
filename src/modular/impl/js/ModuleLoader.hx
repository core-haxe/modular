package modular.impl.js;

import haxe.io.Path;
import js.Browser;
import js.Syntax;
import logging.Logger;
import promises.Promise;

using StringTools;

class ModuleLoader extends ModuleLoaderBase {
    private var log = new Logger(ModuleLoader);
    public var suffix:String = null;

    public override function load(name:String):Promise<modular.ModuleLoader> {
        return new Promise((resolve, reject) -> {
            var filename = Path.normalize(name);
            if (!StringTools.endsWith(filename, ".js")) {
                filename += ".js";
            }
            if (suffix != null && suffix.trim().length > 0) {
                filename += "?" + suffix;
            }

            log.info('loading js module "${filename}"');
            var scriptEl = Browser.document.createScriptElement();
            scriptEl.onload = (_) -> {
                resolve(this);
            }
            scriptEl.onerror = (err) -> {
                reject(err);
            }
            scriptEl.src = filename;
            Browser.document.body.appendChild(scriptEl);
        });
    }

    public override function createClassInstance<T>(name:String, type:Class<T> = null):T {
        var ref = js.Syntax.code("window");
        var parts = name.split(".");
        for (part in parts) {
            ref = js.Syntax.code("{0}[{1}]", ref, part);
            if (ref == null) {
                break;
            }
        }
        if (ref == null) {
            return null;
        }

        if (type == null) {
            var inst:Dynamic = js.Syntax.code("new {0}", ref);
            return inst;
        }

        var inst:T = js.Syntax.code("new {0}", ref);
        return inst;
    }
}