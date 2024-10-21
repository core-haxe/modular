package modular.impl.nodejs;

import js.Node;
import promises.Promise;
import haxe.io.Path;
import logging.Logger;

class ModuleLoader extends ModuleLoaderBase {
    private var log = new Logger(ModuleLoader);

    private var module:Dynamic = null;
    public override function load(name:String):Promise<modular.ModuleLoader> {
        return new Promise((resolve, reject) -> {
            var filename = "./" + Path.normalize("./" + name + ".js");
            log.info('loading nodejs module "${filename}"');
            module = Node.require(filename);
            // bad idea? Its so we can create classes without having to ref the module - modular lib should take care of not loading things twice
            // to global shouldnt get polluted by duplicates
            mergeIntoGlobal(module, js.Syntax.code("global"));
            resolve(this);
        });
    }

    public static function mergeIntoGlobal(object:Dynamic, ref:Dynamic) {
        for (fieldName in Reflect.fields(object)) {
            if (Type.typeof(Reflect.field(object, fieldName)) != TObject) {
                continue;
            }
            var refHasField = Reflect.hasField(ref, fieldName);
            if (!refHasField) {
                Reflect.setField(ref, fieldName, Reflect.field(object, fieldName));
            } else {
                var field = Reflect.field(object, fieldName);
                var refField = Reflect.field(ref, fieldName);
                mergeIntoGlobal(field, refField);
            }
        }
    }

    public override function createClassInstance<T>(name:String, type:Class<T> = null):T {
        var ref = module;
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