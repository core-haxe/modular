package modular;

typedef ModuleClassDescriptor = {
    var name:String;
    @:optional var singleton:Bool;
    @:optional var interfaces:Array<String>;
}