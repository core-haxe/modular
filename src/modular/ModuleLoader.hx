package modular;

#if modular_host

#if cpp

typedef ModuleLoader = modular.impl.cppia.ModuleLoader;

#elseif (nodejs || hxnodejs)

typedef ModuleLoader = modular.impl.nodejs.ModuleLoader;

#elseif js

typedef ModuleLoader = modular.impl.js.ModuleLoader;

#else

typedef ModuleLoader = modular.impl.fallback.ModuleLoader;

#end

#end