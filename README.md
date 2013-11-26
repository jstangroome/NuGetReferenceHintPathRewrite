NuGetReferenceHintPathRewrite
=============================

What problem does this package solve?
-------------------------------------

Whenever installing or updating a NuGet Package for one or more Projects in Visual Studio, at least two things happen:

1.	The NuGet Package is extracted to the \packages\ folder under the current Solution folder.
2.	For each relevant Assembly within the package, a Reference is added or updated in the 

Project and the Reference's HintPath is set to the (relative) path to the Assembly within the current Solution's \packages\ folder.

For Projects that are only included within a single Solution this is not an issue. Whether the \packages\ folder is committed to source control or Package Restore is used instead (preferred), when the Solution is built in a clean workspace (eg the Build Server), the Package Assemblies will be found at the location specified in each Reference HintPath.

However, for Projects that are included in multiple Solutions (each with its own \packages\ folder) build failures will occur in clean workspaces. This is what happens in a Package Restore scenario:

1.	With "SolutionA" open, a Package is installed or updated in "Project1".
2.	The Reference HintPath for the Package in "Project1" refers to "SolutionA\packages\...".
3.	"SolutionB" which also includes "Project1" is then built in clean workspace.
4.	NuGet Package Restore determines all the Packages required for all Projects in "SolutionB", including "Project1" and extracts the Package files to "SolutionB\packages\...".
5.	MSBuild attempts to resolve the Assembly references for "Project1" using the HintPath value of "SolutionA\packages\..." which is missing, or empty.
6.	The build for "Project1" fails.

Even if the Packages are committed to source control instead of using Package Restore, the Build Definition to build "SolutionB" will not include the "SolutionA\packages\" folder in its workspace mappings.

The naive solution
-----------

A common solution to this problem, and the one used until the introduction of the NuGetReferenceHintPathRewrite Package was to modify the HintPath value of each NuGet Package Reference for each Project included in multiple Solutions. The new HintPath value would use the MSBuild Property "$(SolutionDir)" so that the path to the \packages\ folder is calculated based on the current Solution being built.

This solution is not ideal because:

1.	It is tedious to do manually because Project files (eg "*.csproj") cannot be edited in Visual Studio while the Project is loaded.
2.	Each time a Package is installed or updated, this modification needs to be repeated.
3.	Even if the HintPath modification is automated, it is easy to miss this step before committing changes to Source Control.

The solution implemented by the NuGetReferenceHintPathRewrite package
------------------

Instead of modifying the HintPath as persisted in the Project files, the NuGetReferenceHintPathRewrite package modifies the HintPath for each Reference dynamically during the build process

When the Rewrite package is installed into a Project, the following steps are performed:

1.	An MSBuild file called "NuGetReferenceHintPathRewrite.targets" is copied to the Project folder.
2.	The Project file is modified to Import this targets file so that it is executed during the Project build process.
3.	The targets file is also added as a Project item with a Build Action of "None" so that it is clearly visible and to help ensure it is committed to Source Control.
4.	The NuGetReferenceHintPathRewrite package is marked as a development-only dependency in the Project's packages.config file so that it is not included in the dependency chain of another NuGet package containing the Project.

When the MSBuild targets file is Imported into a Project it will:

1.	Hook into the build process before the standard "ResolveAssemblyReferences" stage which is when the build attempts to locate each referenced Assembly using HintPaths and other resolution techniques.
2.	Identify which Project References have a HintPath defined using a path including a "\packages\" folder*. 
3.	Calculate the new HintPath for each identified Reference by combining the currently building Solution's "\packages\" folder** with the portion of the original HintPath that proceeded the original "\packages\" folder. For example:
"..\..\SolutionA\packages\PackageAlpha.1.2.3\lib\AssemblyAlpha.dll" could become "..\AnotherFolder\SolutionB\packages\PackageAlpha.1.2.3\lib\AssemblyAlpha.dll"
4.	Update the affected Project References with the corresponding newly calculated HintPath.

In its current design, the NuGetReferenceHintPathRewrite needs to be installed in each individual Project that will be included in multiple Solutions.

*References without a HintPath defined or with a HintPath not referring to a "\packages\" folder are skipped so that only NuGet References should be affected. However, if a Project uses non-NuGet References under a folder called "\packages\" the HintPath may be incorrectly rewritten. The simplest solution would be to relocate such References.

**The "\packages\" folder of the currently building Solution is assumed to be an immediately subfolder of the path defined in MSBuild's $(SolutionDir) Property. This default, if inappropriate, can be overridden by defining a HintPathPackageDir MSBuild Property with the preferred path.
