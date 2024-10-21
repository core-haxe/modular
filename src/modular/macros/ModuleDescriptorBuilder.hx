package modular.macros;

import haxe.macro.Expr.Field;
#if macro

import haxe.macro.Context;

class ModuleDescriptorBuilder {
    public static function build() {
        var fields = Context.getBuildFields();
        if (!hasField(fields, "init")) {
            fields.push({
                name: "init",
                access: [APublic],
                kind: FVar(macro: Void->Void, macro null),
                pos: Context.currentPos()
            });
        }
        if (!hasField(fields, "wireModule")) {
            fields.push({
                name: "wireModule",
                access: [APublic],
                kind: FVar(macro: Dynamic->Void, macro function(wire) {
                    if (wire.resolveClass != null || wire.resolveEnum != null) {
                        haxe.Unserializer.DEFAULT_RESOLVER = {
                            resolveClass: function(name:String) {
                                if (wire.resolveClass != null) {
                                    return wire.resolveClass(name);
                                }
                                return Type.resolveClass(name);
                            },
                            resolveEnum: function(name:String) {
                                if (wire.resolveEnum != null) {
                                    return wire.resolveEnum(name);
                                }
                                return Type.resolveEnum(name);
                            }
                        }
                    }
                }),
                pos: Context.currentPos()
            });
        }
        if (!hasField(fields, "resources")) {
            fields.push({
                name: "resources",
                access: [APublic],
                kind: FVar(macro: Array<{name:String, data:String, str:String}>, macro null),
                pos: Context.currentPos()
            });
        }
        if (!hasField(fields, "classes")) {
            fields.push({
                name: "classes",
                access: [APublic],
                kind: FVar(macro: Array<ModuleClassDescriptor>, macro []),
                pos: Context.currentPos()
            });
        }
        if (!hasField(fields, "dependencies")) {
            fields.push({
                name: "dependencies",
                access: [APublic],
                kind: FVar(macro: Array<String>, macro []),
                pos: Context.currentPos()
            });
        }
        return fields;
    }

    private static function hasField(fields:Array<Field>, name:String):Bool {
        for (f in fields) {
            if (f.name == name) {
                return true;
            }
        }
        return false;
    }
}

#end