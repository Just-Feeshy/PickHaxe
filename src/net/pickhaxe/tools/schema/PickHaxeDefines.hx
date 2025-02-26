package net.pickhaxe.tools.schema;

import net.pickhaxe.tools.util.Error.NoProjectXMLException;
import net.pickhaxe.tools.util.Error.UnknownLoaderException;
import net.pickhaxe.tools.schema.PickHaxeProject.HaxelibEntry;
import net.pickhaxe.tools.schema.FabricMeta.FabricMetaLoaderVersionData;
import net.pickhaxe.api.Parchment;
import net.pickhaxe.api.FabricMeta;
import net.pickhaxe.api.Mojang;
import net.pickhaxe.tools.Constants;
import net.pickhaxe.tools.schema.FabricMeta.FabricMetaIntermediaryDataItem;
import net.pickhaxe.tools.schema.FabricMeta.FabricMetaLoaderData;
import net.pickhaxe.tools.schema.FabricMeta.FabricMetaLoaderDataItem;
import net.pickhaxe.tools.schema.FabricMeta.FabricMetaYarnDataItem;
import net.pickhaxe.tools.schema.MinecraftManifest.VersionData;
import net.pickhaxe.tools.schema.MinecraftManifest.VersionManifest;
import net.pickhaxe.tools.schema.PickHaxeVersionMappings.PickHaxeVersionMappingsReader;
import net.pickhaxe.tools.schema.PickHaxeVersionMetadata.PickHaxeVersionMetadataReader;
import net.pickhaxe.tools.util.MCVersion;

/**
 * Gather all the compile defines together so they can be reused and referenced.
 */
typedef PickHaxeDefines =
{
  pickhaxe:PickHaxeDefinesPickHaxe,
};

typedef PickHaxeDefinesPickHaxe =
{
  version:String,
  haxe:
  {
    libraries:Array<HaxelibEntry>, version:String, jvm:String
  },
  gradle:
  {
    version:String,
    plugins:
    {
      forgegradle:String,
    }
  },
  java:
  {
    version:String,
  },
  minecraft:
  {
    release:Bool, snapshot:Bool, version:String, resourcePackFormat:Int, dataPackFormat:Int,
  },
  loader:
  {
    current:String, fabric:
    {
      apiVersion:String, loaderVersion:String,
    }, forge:
    {
      apiVersion:String, fmlVersion:String,
    }
  },
  mappings:
  {
    enabled:Bool, current:String, yarn:
    {
      version:String
    }, parchment:
    {
      maven:String, version:String
    }, intermediary:
    {
      maven:String, version:String
    },
  },
  mod:PickHaxeDefinesMod,
}

typedef PickHaxeDefinesMod =
{
  classPath:String,
  id:String,
  name:String,
  parentPackage:String,
  version:String,
  description:String,
  entryPoints:Array<PickHaxeProject.ModEntryPoint>,
  dependencies:Array<PickHaxeProject.ModDependency>,
  license:String,

  authorData:AuthorData,

  homepage:String,
  email:String,
  issues:String,
  sources:String,
}

typedef AuthorData = {
  /**
   * A comma separated list of author names with no contact info.
   * Used by Forge.
   */
  authorsString:String,
  /**
   * An array of authors (either strings or objects with name and contact info).
   * Used by Fabric.
   */
  authors:Array<net.pickhaxe.schema.FabricMod.Person>,
  /**
   * An array of contributors (either strings or objects with name and contact info).
   * Used by Fabric.
   */
  contributors:Array<net.pickhaxe.schema.FabricMod.Person>,
}

typedef 
BuildParams =
{
  loader:String,
  mcVersion:String,
  jvm:Bool,
  ?noMapping:Bool,
  ?mappings:String,
}

/**
 * Fills out the PickHaxeDefines based on the current environment.
 */
class Builder
{
  /**
   * The Haxe compiler flag to add defines.
   */
  static final DEFINE:String = '--define';

  /**
   * Builds the defines for the current environment.
   * @param mcVersion The Minecraft version to build for.
   * @param loader The loader to build for.
   * @return An object of compile defines.
   */
  public static function build(params:BuildParams):PickHaxeDefines
  {
    params = validateBuildParams(params);

    CLI.print("Reading project file...");

    var projectFile:PickHaxeProject = net.pickhaxe.tools.util.XML.readProjectFile(IO.workingDir().joinPaths('project.xml'));

    if (projectFile == null)
    {
      throw new NoProjectXMLException();
    }

    CLI.print("Read project file.");

    return switch (params.loader)
    {
      case 'fabric': buildFabric(projectFile, params);
      case 'forge': buildForge(projectFile, params);
      default: throw 'Unknown loader: ' + params.loader;
    }
  }

  /**
   * Throws when required values are missing, and populates defaults.
   */
  static function validateBuildParams(params:BuildParams):BuildParams
  {
    if (params.loader == null) throw 'Loader must be specified.';
    if (params.mcVersion == null) throw 'Minecraft version must be specified.';

    if (params.mcVersion == 'latest') params.mcVersion = MCVersion.getLatestStableVersion();
    if (params.mcVersion == 'latest-snapshot') params.mcVersion = MCVersion.getLatestVersion();

    params.noMapping = params.noMapping ?? false;
    params.mappings = params.mappings ?? 'parchment';

    return params;
  }

  static function buildFabric(projectFile:PickHaxeProject, params:BuildParams):PickHaxeDefines
  {
    var versionMetadata:PickHaxeVersionMetadata = PickHaxeVersionMetadataReader.read(params.mcVersion, MCVersion.isVersionStable(params.mcVersion));

    var mojangVersionData:VersionData = Mojang.fetchVersionData(params.mcVersion);
    if (mojangVersionData == null)
    {
      throw 'Could not load Mojang version data from API for version ${params.mcVersion}';
    }
    else
    {
      CLI.print('Mojang version: ${mojangVersionData.id}', Verbose);
    }

    var fabricLoaderData:FabricMetaLoaderVersionData = FabricMeta.fetchLoaderDataForGameVersion(params.mcVersion)[0];
    if (fabricLoaderData == null)
    {
      throw 'Could not load Fabric loader data from API for version ${params.mcVersion}';
    }
    else
    {
      CLI.print('Fabric loader version: ${fabricLoaderData.loader.version}', Verbose);
    }

    var fabricYarnData:FabricMetaYarnDataItem = FabricMeta.fetchYarnData(params.mcVersion)[0];
    if (fabricYarnData == null)
    {
      throw 'Could not load Fabric Yarn data from API for version ${params.mcVersion}';
    }
    else
    {
      CLI.print('Fabric yarn version: ${fabricYarnData.version}', Verbose);
    }

    var fabricIntermediaryData:FabricMetaIntermediaryDataItem = FabricMeta.fetchIntermediaryData(params.mcVersion)[0];
    if (fabricIntermediaryData == null)
    {
      throw 'Could not load Fabric Intermediary data from API for version ${params.mcVersion}';
    }
    else
    {
      CLI.print('Fabric intermediary version: ${fabricIntermediaryData.version}', Verbose);
    }

    var currentMappings:String = params.mappings;

    var parchmentVersion:String = Parchment.fetchParchmentVersion(params.mcVersion);
    var parchmentMaven:String = 'parchment-${params.mcVersion}:${parchmentVersion}';
    if (params.mappings == 'parchment')
    {
      // Make behavior intuitive:
      // If the current version is a snapshot, we check for mappings of the previous snapshot.
      // Otherwise, we check for mappings of the previous release.
      var isSnapshot = MCVersion.isVersionSnapshot(params.mcVersion);

      var currentVersion = params.mcVersion;
      var previousVersion:String = params.mcVersion;
      while (parchmentVersion == null)
      {
        previousVersion = isSnapshot ? MCVersion.getPreviousSnapshotVersion(previousVersion) : MCVersion.getPreviousVersion(previousVersion);

        if (previousVersion == null)
        {
          CLI.print('Warning: Could not load Parchment version from API for version $previousVersion, falling back to plain MojMaps with no Parchment.');
          currentMappings = 'mojang';
          break;
        }
        else
        {
          CLI.print('Warning: Could not load Parchment version from API for version ${currentVersion}, trying $previousVersion');
        }

        currentVersion = previousVersion;

        parchmentVersion = Parchment.fetchParchmentVersion(currentVersion);

        if (parchmentVersion == null)
        {
          continue;
        }
        else
        {
          // Reformat the mappings version.
          CLI.print('Success: Loaded Parchment version from API for version $currentVersion. (Parchment version: $parchmentVersion)');
          parchmentMaven = 'parchment-${currentVersion}:${parchmentVersion}';
          parchmentVersion = '${parchmentVersion}-${currentVersion}';
        }
      }
    }

    var fabricAPIVersion:String = FabricMeta.getApiVersionForMinecraft(params.mcVersion);
    if (fabricAPIVersion == null) throw 'Could not load Fabric API version from API for version ${params.mcVersion}';

    var authors:Array<net.pickhaxe.schema.FabricMod.Person> = [for (author in projectFile.authors) Right({
      name: author.name,
      contact: {
        homepage: author.homepage,
        email: author.email,
        issues: author.issues,
        sources: author.sources,
      },
    })];

    var contributors:Array<net.pickhaxe.schema.FabricMod.Person> = [for (contributor in projectFile.contributors) Right({
      name: contributor.name,
      contact: {
        homepage: contributor.homepage,
        email: contributor.email,
        issues: contributor.issues,
        sources: contributor.sources,
      },
    })];

    return {
      pickhaxe:
        {
          version: Constants.LIBRARY_VERSION,

          haxe:
            {
              libraries: projectFile.haxelibs,
              version: Constants.HAXE_VERSION,
              jvm: params.jvm ? 'true' : 'false',
            },

          java:
            {
              version: '${mojangVersionData.javaVersion.majorVersion}'
            },

          // TODO: Test if Gradle versions are properly backwards compatible.
          // If Forge doesn't work with Gradle 8, we'll need to add to the metadata.json.
          gradle:
            {
              version: versionMetadata.fabricGradleVersion,
              plugins: {
                forgegradle: versionMetadata.forgeGradlePluginVersion,
              }
            },

          minecraft:
            {
              dataPackFormat: MCVersion.getDataPackFormat(params.mcVersion),
              resourcePackFormat: MCVersion.getResourcePackFormat(params.mcVersion),
              snapshot: MCVersion.isVersionSnapshot(params.mcVersion),
              release: MCVersion.isVersionStable(params.mcVersion),
              version: params.mcVersion
            },

          loader:
            {
              current: 'fabric',
              fabric:
                {
                  apiVersion: fabricAPIVersion, // TODO: Determine this value from the Fabric API version.
                  loaderVersion: fabricLoaderData.loader.version
                },
              forge:
                {
                  apiVersion: null,
                  fmlVersion: null,
                },
            },

          mappings:
            {
              enabled: !params.noMapping,
              current: currentMappings,
              yarn:
                {
                  version: fabricYarnData.version,
                },
              parchment:
                {
                  maven: parchmentMaven,
                  version: parchmentVersion,
                },
              intermediary:
                {
                  maven: fabricIntermediaryData.maven,
                  version: fabricIntermediaryData.version,
                }
            },

          mod:
            {
              id: projectFile.mod.id,
              version: projectFile.mod.version,
              name: projectFile.metadata.name,
              description: projectFile.metadata.description,
              classPath: projectFile.mod.classPath,
              parentPackage: projectFile.mod.parentPackage,

              entryPoints: projectFile.entryPoints,

              dependencies: projectFile?.dependencies ?? [],

              // Default license
              license: projectFile?.license?.value ?? 'All Rights Reserved',

              authorData: {
                authorsString: '', // Unused by Fabric.
                authors: authors,
                contributors: contributors,
              },

              homepage: projectFile?.contact?.homepage ?? null,
              email: projectFile?.contact?.email ?? null,
              issues: projectFile?.contact?.issues ?? null,
              sources: projectFile?.contact?.sources ?? null,
            },
        }
    };
  }

  static function buildForge(projectFile:PickHaxeProject, params:BuildParams):PickHaxeDefines
  {
    var versionMetadata:PickHaxeVersionMetadata = PickHaxeVersionMetadataReader.read(params.mcVersion, MCVersion.isVersionStable(params.mcVersion));
    var versionMappings:PickHaxeVersionMappings = PickHaxeVersionMappingsReader.read(params.mcVersion, MCVersion.isVersionStable(params.mcVersion));

    var currentMappings:String = params.mappings;

    var parchmentVersion:String = Parchment.fetchParchmentVersion(params.mcVersion);
    var parchmentMaven:String = 'parchment-${params.mcVersion}:${parchmentVersion}';
    if (currentMappings == 'parchment')
    {
      // Make behavior intuitive:
      // If the current version is a snapshot, we check for mappings of the previous snapshot.
      // Otherwise, we check for mappings of the previous release.
      var isSnapshot = MCVersion.isVersionSnapshot(params.mcVersion);

      var currentVersion = params.mcVersion;
      var previousVersion:String = params.mcVersion;
      while (parchmentVersion == null)
      {
        previousVersion = null; // isSnapshot ? MCVersion.getPreviousSnapshotVersion(params.mcVersion) : MCVersion.getPreviousVersion(currentVersion);

        if (previousVersion == null)
        {
          CLI.print('Warning: Could not load Parchment version from API for version $previousVersion, falling back to plain MojMaps with no Parchment.');
          currentMappings = 'mojang';
          break;
        }
        else
        {
          CLI.print('Warning: Could not load Parchment version from API for version ${currentVersion}, trying $previousVersion');
        }

        currentVersion = previousVersion;

        parchmentVersion = Parchment.fetchParchmentVersion(currentVersion);

        if (parchmentVersion == null)
        {
          continue;
        }
        else
        {
          // Reformat the mappings version.
          CLI.print('Success: Loaded Parchment version from API for version $previousVersion. (Parchment version: $parchmentVersion)');
          parchmentMaven = 'parchment-${previousVersion}:${parchmentVersion}';
          parchmentVersion = '${parchmentVersion}-${previousVersion}';
        }
      }
    }

    var authorsStringParts:Array<String> = [];

    for (author in projectFile.authors)
    {
      var authorName:String = author.name;
      if (authorName != null) authorsStringParts.push(authorName);
    }
  
    for (contributor in projectFile.contributors)
    {
      var contributorName:String = contributor.name;
      if (contributorName != null) authorsStringParts.push(contributorName);
    }
  
    var authorsString:String = authorsStringParts.join(', ');

    return {
      pickhaxe:
        {
          version: Constants.LIBRARY_VERSION,

          haxe:
            {
              libraries: projectFile.haxelibs,
              version: Constants.HAXE_VERSION,
              jvm: params.jvm ? 'true' : 'false',
            },

          java:
            {
              version: versionMetadata.javaVersion
            },

          gradle:
            {
              version: versionMetadata.forgeGradleVersion,
              plugins: {
                forgegradle: versionMetadata.forgeGradlePluginVersion,
              }
            },

          minecraft:
            {
              dataPackFormat: MCVersion.getDataPackFormat(params.mcVersion),
              resourcePackFormat: MCVersion.getResourcePackFormat(params.mcVersion),
              release: MCVersion.isVersionStable(params.mcVersion),
              snapshot: MCVersion.isVersionSnapshot(params.mcVersion),
              version: params.mcVersion
            },

          loader:
            {
              current: 'forge',
              forge:
                {
                  apiVersion: versionMetadata.forgeVersion,
                  fmlVersion: versionMetadata.fmlVersion,
                },
              fabric:
                {
                  apiVersion: null,
                  loaderVersion: null
                }
            },

          mappings:
            {
              enabled: !params.noMapping,
              current: currentMappings,
              parchment:
                {
                  version: parchmentVersion,
                  maven: parchmentMaven
                },
              yarn:
                {
                  version: null,
                },
              intermediary:
                {
                  maven: null,
                  version: null,
                }
            },

          mod:
            {
              id: projectFile.mod.id,
              version: projectFile.mod.version,
              name: projectFile.metadata.name,
              description: projectFile.metadata.description,
              classPath: projectFile.mod.classPath,
              parentPackage: projectFile.mod.parentPackage,

              entryPoints: projectFile.entryPoints,

              dependencies: projectFile?.dependencies ?? [],

              license: projectFile?.license?.value ?? 'All Rights Reserved',

              authorData: {
                authorsString: authorsString,
                authors: [], // Unused by Forge.
                contributors: [], // Unused by Forge.
              },

              homepage: projectFile?.contact?.homepage ?? null,
              email: projectFile?.contact?.email ?? null,
              issues: projectFile?.contact?.issues ?? null,
              sources: projectFile?.contact?.sources ?? null,
            },
        }
    };
  }

  public static function toHaxeDefines(defines:PickHaxeDefines):Array<String>
  {
    var result:Array<String> = [];

    // result = result.concat(DEFINE, 'pickhaxe.version=' + defines.pickhaxe.version); // Use `pickhaxe` instead.
    // result.append(DEFINE, 'pickhaxe.gradle.version=${defines.pickhaxe.gradle.version}'); // Use `haxe` instead.
    result.append(DEFINE, 'pickhaxe.haxe.jvm=${defines.pickhaxe.haxe.jvm}');
    result.append(DEFINE, 'pickhaxe.gradle.version=${defines.pickhaxe.gradle.version}');
    result.append(DEFINE, 'pickhaxe.java.version=${defines.pickhaxe.java.version}');
    result.append(DEFINE, 'pickhaxe.loader.current=${defines.pickhaxe.loader.current}');
    if (defines.pickhaxe.loader.fabric.apiVersion != null) result.append(DEFINE,
      'pickhaxe.loader.fabric.apiVersion=${defines.pickhaxe.loader.fabric.apiVersion}');
    if (defines.pickhaxe.loader.fabric.loaderVersion != null) result.append(DEFINE,
      'pickhaxe.loader.fabric.loaderVersion=${defines.pickhaxe.loader.fabric.loaderVersion}');
    if (defines.pickhaxe.loader.forge.apiVersion != null) result.append(DEFINE,
      'pickhaxe.loader.forge.apiVersion=${defines.pickhaxe.loader.forge.apiVersion}');
    result.append(DEFINE, 'pickhaxe.mappings.enabled=${defines.pickhaxe.mappings.enabled}');
    result.append(DEFINE, 'pickhaxe.mappings.current=${defines.pickhaxe.mappings.current}');
    if (defines.pickhaxe.mappings.intermediary.maven != null) result.append(DEFINE,
      'pickhaxe.mappings.intermediary.maven=${defines.pickhaxe.mappings.intermediary.maven}');
    if (defines.pickhaxe.mappings.intermediary.version != null) result.append(DEFINE,
      'pickhaxe.mappings.intermediary.version=${defines.pickhaxe.mappings.intermediary.version}');
    if (defines.pickhaxe.mappings.parchment.maven != null) result.append(DEFINE,
      'pickhaxe.mappings.parchment.maven=${defines.pickhaxe.mappings.parchment.maven}');
    if (defines.pickhaxe.mappings.parchment.version != null) result.append(DEFINE,
      'pickhaxe.mappings.parchment.version=${defines.pickhaxe.mappings.parchment.version}');
    if (defines.pickhaxe.mappings.yarn.version != null) result.append(DEFINE, 'pickhaxe.mappings.yarn.version=${defines.pickhaxe.mappings.yarn.version}');
    result.append(DEFINE, 'pickhaxe.minecraft.version=${defines.pickhaxe.minecraft.version}');
    result.append(DEFINE, 'pickhaxe.minecraft.resourcePackFormat=${defines.pickhaxe.minecraft.resourcePackFormat}');
    result.append(DEFINE, 'pickhaxe.minecraft.dataPackFormat=${defines.pickhaxe.minecraft.dataPackFormat}');
    result.append(DEFINE, 'pickhaxe.mod.classPath=${defines.pickhaxe.mod.classPath}');
    result.append(DEFINE, 'pickhaxe.mod.description=${defines.pickhaxe.mod.description}');
    result.append(DEFINE, 'pickhaxe.mod.id=${defines.pickhaxe.mod.id}');
    result.append(DEFINE, 'pickhaxe.mod.name=${defines.pickhaxe.mod.name}');
    result.append(DEFINE, 'pickhaxe.mod.parentPackage=${defines.pickhaxe.mod.parentPackage}');
    result.append(DEFINE, 'pickhaxe.mod.version=${defines.pickhaxe.mod.version}');

    // Special defines.

    // Add a define for the current loader (#if fabric, #if forge)
    result.append(DEFINE, defines.pickhaxe.loader.current);

    // Add a define for the current Minecraft version (#if minecraft == 1.19.3, #if minecraft >= 1.12.2)
    result.append(DEFINE, 'minecraft=${defines.pickhaxe.minecraft.version}');

    return result;
  }
}
