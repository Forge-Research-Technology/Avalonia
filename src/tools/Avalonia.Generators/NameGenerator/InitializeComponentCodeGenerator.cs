﻿using System.Collections.Generic;
using Avalonia.Generators.Common.Domain;
using XamlX.TypeSystem;

namespace Avalonia.Generators.NameGenerator;

internal class InitializeComponentCodeGenerator : ICodeGenerator
{
    private string _generatorName = typeof(InitializeComponentCodeGenerator).FullName;
    private string _generatorVersion = typeof(InitializeComponentCodeGenerator).Assembly.GetName().Version.ToString();
    private readonly bool _diagnosticsAreConnected;
    private const string AttachDevToolsCodeBlock = @"
#if DEBUG
            if (attachDevTools)
            {
                this.AttachDevTools();
            }
#endif
";
    private const string AttachDevToolsParameterDocumentation
        = @"        /// <param name=""attachDevTools"">Should the dev tools be attached.</param>
";


    public InitializeComponentCodeGenerator(IXamlTypeSystem types, bool avaloniaNameGeneratorAttachDevTools)
    {
        _diagnosticsAreConnected = avaloniaNameGeneratorAttachDevTools && types.FindAssembly("Avalonia.Diagnostics") != null;
    }

    public string GenerateCode(string className, string nameSpace, IXamlType xamlType, IEnumerable<ResolvedName> names)
    {
        var properties = new List<string>();
        var initializations = new List<string>();
        const string thisFindNameScopeVariable = "            var __thisNameScope__ = this.FindNameScope();";
        bool hasNames = false;

        foreach (var resolvedName in names)
        {
            if (!hasNames)
            {
                initializations.Add(thisFindNameScopeVariable);
            }

            var (typeName, name, fieldModifier) = resolvedName;
            var propertySource =
            $"""
                    [global::System.CodeDom.Compiler.GeneratedCode("{_generatorName}", "{_generatorVersion}")]
                    {fieldModifier} {typeName} {name};
            """;
            properties.Add(propertySource);
            initializations.Add($"            {name} = __thisNameScope__?.Find<{typeName}>(\"{name}\");");

            hasNames = true;
        }

        var attachDevTools = _diagnosticsAreConnected && IsWindow(xamlType);

        return $@"// <auto-generated />

using Avalonia;
using Avalonia.Controls;
using Avalonia.Markup.Xaml;

namespace {nameSpace}
{{
    partial class {className}
    {{
{string.Join("\n", properties)}

        /// <summary>
        /// Wires up the controls and optionally loads XAML markup and attaches dev tools (if Avalonia.Diagnostics package is referenced).
        /// </summary>
        /// <param name=""loadXaml"">Should the XAML be loaded into the component.</param>
{(attachDevTools ? AttachDevToolsParameterDocumentation : string.Empty)}
        [global::System.CodeDom.Compiler.GeneratedCode(""{_generatorName}"", ""{_generatorVersion}"")]
        [global::System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage]
        public void InitializeComponent(bool loadXaml = true{(attachDevTools ? ", bool attachDevTools = true" : string.Empty)})
        {{
            if (loadXaml)
            {{
                AvaloniaXamlLoader.Load(this);
            }}
{(attachDevTools ? AttachDevToolsCodeBlock : string.Empty)}
{string.Join("\n", initializations)}
        }}
    }}
}}
";
    }

    private static bool IsWindow(IXamlType xamlType)
    {
        var type = xamlType;
        bool isWindow;
        do
        {
            isWindow = type.FullName == "Avalonia.Controls.Window";
            type = type.BaseType;
        } while (!isWindow && type != null);

        return isWindow;
    }
}
