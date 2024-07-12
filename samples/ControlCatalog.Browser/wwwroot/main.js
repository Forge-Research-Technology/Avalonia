// Licensed to the .NET Foundation under one or more agreements.
// The .NET Foundation licenses this file to you under the MIT license.

<<<<<<<< HEAD:samples/ControlCatalog.Browser/AppBundle/main.js
import { dotnet } from './dotnet.js' // NET 7
//import { dotnet } from './_framework/dotnet.js' // NET 8+
========
import { dotnet } from './_framework/dotnet.js'
>>>>>>>> upstream/release/11.1.0-rc2:samples/ControlCatalog.Browser/wwwroot/main.js

const is_browser = typeof window != "undefined";
if (!is_browser) throw new Error(`Expected to be running in a browser`);

const dotnetRuntime = await dotnet
    .withApplicationArgumentsFromQuery()
    .create();

const config = dotnetRuntime.getConfig();

<<<<<<<< HEAD:samples/ControlCatalog.Browser/AppBundle/main.js
await dotnetRuntime.runMainAndExit(config.mainAssemblyName, [globalThis.location.href]);
========
await dotnetRuntime.runMain(config.mainAssemblyName, [globalThis.location.href]);
>>>>>>>> upstream/release/11.1.0-rc2:samples/ControlCatalog.Browser/wwwroot/main.js
