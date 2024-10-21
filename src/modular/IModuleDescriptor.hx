package modular;

import haxe.Resource;

@:autoBuild(modular.macros.ModuleDescriptorBuilder.build())
interface IModuleDescriptor {
    var name:String;
    var description:String;
    var version:ModuleVersion;
    var classes:Array<ModuleClassDescriptor>;
    var resources:Array<{name:String, data:String, str:String}>;
    var dependencies:Array<String>;
    var init:Void->Void;
    var wireModule:Dynamic->Void;
}