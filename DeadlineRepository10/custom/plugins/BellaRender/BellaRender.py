#!/usr/bin/env python3

from Deadline.Plugins import *
from Deadline.Scripting import FileUtils, SystemUtils, RepositoryUtils, FileUtils, PathUtils, FrameUtils, StringUtils
from System.Diagnostics import *

from pathlib import Path
import shutil
import math as m
import random
import sys
import os

cam_mat4 = [[-0.991192, 0, 0, 0],
            [0, 0, -1, 0],
            [0, 0.991192, -0.13243, 0],
            [0, -155.109, 29.1869, 1]]

def GetDeadlinePlugin():
    """Deadline calls to get an instance of DeadlinePlugin class"""
    return BellaRenderPlugin()

def CleanupDeadlinePlugin(deadlinePlugin):
    """Deadline calls this when the plugin is no longer in use"""
    deadlinePlugin.Cleanup()

class BellaRenderPlugin(DeadlinePlugin):
    sceneFile = ""
    sceneFilesStem = ""
    outputDirectory = ""
    outputExt = ""
    outputName = ""
    def __init__(self):
        """setup Deadline callbacks"""
        if sys.version_info.major == 3:
            super().__init__()
        self.InitializeProcessCallback += self.InitializeProcess
        self.PreRenderTasksCallback += self.PreRenderTasks
        self.RenderExecutableCallback += self.RenderExecutable
        self.RenderArgumentCallback += self.RenderArgument
        self.PostRenderTasksCallback += self.PostRenderTasks

    def Cleanup(self):
        """Clean up the plugin."""
        # Clean up stdout handler callbacks
        for stdoutHandler in self.StdoutHandlers:
            del stdoutHandler.HandleCallback

        del self.InitializeProcessCallback
        del self.RenderExecutableCallback
        del self.RenderArgumentCallback

    def InitializeProcess(self):
        """Called by Deadline"""
        self.SingleFramesOnly = False
        self.PluginType = PluginType.Simple

        self.ProcessPriority = ProcessPriorityClass.BelowNormal
        self.UseProcessTree = True
        self.StdoutHandling = True
        bella_lic = Path('/mnt/oomerfarm/bella/bella.lic')
        if bella_lic.exists():
            self.SetEnvironmentVariable("BELLA_LICENSE_TEXT",bella_lic.read_text())
        self.AddStdoutHandlerCallback(
            "(\[WARNING\])").HandleCallback += self.HandleStdoutWarning
        # [ ] bella_cli currently has a lot of non critical error messages
        # [ ] should be critical for texture or reference fails
        # [ ] should allow the user to have a strict mode, I think bella_cli support is planned for strict
        #self.AddStdoutHandlerCallback(
        #    "(\[ERROR\])").HandleCallback += self.HandleStdoutError
        self.AddStdoutHandlerCallback( 
            "(Progress: [0-9]*.[0-9]*%)" ).HandleCallback += self.HandleProgress

    def HandleStdoutWarning(self):
        self.LogWarning(self.GetRegexMatch(0))

    def HandleStdoutError(self):
        self.FailRender("Error: " + self.GetRegexMatch(1))

    def HandleProgress( self ):
        # Regex input is in string form "Progress: 68.78%""
        self.SetProgress( float(self.GetRegexMatch(1)[9:-1]) )

    def PreRenderTasks( self ):
        # This Plugin instance knows what frame it is working on via self.getStartFrame()
        # Substitute work frame into sceneFile string
        sceneFile = self.GetPluginInfoEntry( "sceneFile" ).strip()
        # GUI Configure Repository Options -> Mapped Paths
        sceneFile = RepositoryUtils.CheckPathMapping( sceneFile )

        outputDirectory = self.GetPluginInfoEntry( "outputDirectory" ).strip()  
        outputDirectory = RepositoryUtils.CheckPathMapping( outputDirectory )
        
        sceneFile = sceneFile.replace( "\\", "/" ) #win
        sceneFile = sceneFile.replace("//10.10.0.1","/mnt") #win
        sceneFile = sceneFile.replace("/Volumes","/mnt") #mac

        outputDirectory = outputDirectory.replace( "\\", "/" ) #win
        outputDirectory = outputDirectory.replace("//10.10.0.1","/mnt") #win
        outputDirectory = outputDirectory.replace("/Volumes","/mnt") #mac
        
        self.outputExt = self.GetPluginInfoEntryWithDefault( "outputExt", "").strip()
        if self.outputExt == 'default':
            self.outputExt = '.png'

        ##padded frame stuff is messing with smb octet name
	## OOF problem is the smb path //10.10.0.1 is being replaced with //10.10.$framenumber.1
        # should be fine if //10.10.0.1 is converted to /mnt before padding is done
        # suspect that GetFrameStringFromFilename just looks for last num.* pattern 
	## [TODO] write my own function without this problem

        sceneFileFramePadded = FrameUtils.GetFrameStringFromFilename( sceneFile )
        paddingSize = len( sceneFileFramePadded )
        print('userFramePadded', sceneFileFramePadded, 'paddingSize', paddingSize) 
        if paddingSize > 0:
            # current frame
            renderFramePadded = StringUtils.ToZeroPaddedString( self.GetStartFrame(), paddingSize, False )
            self.sceneFile = FrameUtils.SubstituteFrameNumber( sceneFile, renderFramePadded )
        else:
            self.sceneFile = sceneFile
        self.outputDirectory = outputDirectory

    def PostRenderTasks( self ):
        tempPath = Path(PathUtils.GetSystemTempPath())
        print( tempPath / self.outputName, self.outputDirectory)
        shutil.copy( tempPath / self.outputName, self.outputDirectory)

    def RenderExecutable(self):
        """Callback to get executable used for rendering"""
        executableList =  self.GetConfigEntry("BellaRenderPluginRenderExecutable")
        # Goes through semi colon separated list of paths in Bella.param
        # Uses default Diffuse Logic install location for Windows, MacOS and Linux Bella CLI
        executable = FileUtils.SearchFileList( executableList )
        #print(FileUtils.SearchFileList( executableList ),"fileutile",executableList)
        #executable="/usr/local/bin/bella_cli" # [TODO] hardcoded for now, therefore no cross platform rendering for now
        if( executable == "" ): self.FailRender( "Bella render executable not found in plugin search paths" )
        return executable

    def RenderArgument(self):
        """Callback to get arguments passed to the executable"""
        sceneFile = self.sceneFile
        outputDirectory = self.outputDirectory
    
        outputExt = self.outputExt
        imageWidth = self.GetPluginInfoEntryWithDefault( "imageWidth", "").strip()
        imageHeight = self.GetPluginInfoEntryWithDefault( "imageHeight", "").strip()
        targetNoise = self.GetPluginInfoEntryWithDefault( "targetNoise", "").strip()
        useGpu = self.GetPluginInfoEntryWithDefault( "useGpu", "").strip()
        timeLimit = self.GetPluginInfoEntryWithDefault( "timeLimit", "").strip()
        denoiseName = self.GetPluginInfoEntryWithDefault( "denoise", "").strip()

        useFreeformA = self.GetPluginInfoEntryWithDefault( "useFreeformA", "").strip()
        useFreeformB = self.GetPluginInfoEntryWithDefault( "useFreeformB", "").strip()
        useOrbit = self.GetPluginInfoEntryWithDefault( "useOrbit", "").strip()
        if useOrbit == "True": useOrbit = True
        else: useOrbit = False
        if useFreeformA == "True": useFreeformA = True
        else: useFreeformA = False
        if useFreeformB == "True": useFreeformB = True
        else: useFreeformB = False
        if useFreeformA:
            freeformA = self.GetPluginInfoEntryWithDefault( "freeformA", "").strip()
            freeformAStart = float(self.GetPluginInfoEntryWithDefault( "freeformAStart", "").strip())
            freeformAEnd = float(self.GetPluginInfoEntryWithDefault( "freeformAEnd", "").strip())
            animationFrames = int(self.GetPluginInfoEntryWithDefault( "animationFrames", "").strip())
            currentFrame = self.GetStartFrame()
            freeformAStep = float((freeformAEnd-freeformAStart ) / animationFrames)
            freeformAVal = (float(currentFrame-1)*freeformAStep)+freeformAStart
        # [TODO] do step calc here, allowing us to do inteps other than lerp
        elif useFreeformB:
            freeformB = self.GetPluginInfoEntryWithDefault( "freeformB", "").strip()
            freeformBStart = float(self.GetPluginInfoEntryWithDefault( "freeformBStart", "").strip())
            freeformBEnd = float(self.GetPluginInfoEntryWithDefault( "freefromBEnd", "").strip())
            freeformBStep = float(self.GetPluginInfoEntryWithDefault( "freefromBStep", "").strip())
            animationFrames = int(self.GetPluginInfoEntryWithDefault( "animationFrames", "").strip())
            currentFrame = self.GetStartFrame()
            freeformBStep = float((freeformBEnd-freeformBStart ) / animationFrames)
            freeformBVal = (float(currentFrame-1)*freeformBStep)+freeformBStart
        else:
            currentFrame = self.GetStartFrame()
            animationFrames = int(self.GetPluginInfoEntryWithDefault( "animationFrames", "").strip())

        if useOrbit:
            result_mat4 = [[ 0,0,0,0],
                    [0,0,0,0],
                    [0,0,0,0],
                    [0,0,0,0]]
            cam_matrix_a = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_a", "0").strip())
            cam_matrix_b = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_b", "0").strip())
            cam_matrix_c = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_c", "0").strip())
            cam_matrix_d = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_d", "0").strip())
            cam_matrix_e = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_e", "0").strip())
            cam_matrix_f = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_f", "0").strip())
            cam_matrix_g = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_g", "0").strip())
            cam_matrix_h = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_h", "0").strip())
            cam_matrix_i = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_i", "0").strip())
            cam_matrix_j = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_j", "0").strip())
            cam_matrix_k = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_k", "0").strip())
            cam_matrix_l = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_l", "0").strip())
            cam_matrix_m = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_m", "0").strip())
            cam_matrix_n = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_n", "0").strip())
            cam_matrix_o = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_o", "0").strip())
            cam_matrix_p = float(self.GetPluginInfoEntryWithDefault( "cam_matrix_p", "1").strip())
            orbDegrees = float(self.GetPluginInfoEntryWithDefault( "orbDegrees", "0").strip())
            cam_mat4 = [[cam_matrix_a, cam_matrix_b, cam_matrix_c, cam_matrix_d],
                        [cam_matrix_e, cam_matrix_f, cam_matrix_g, cam_matrix_h],
                        [cam_matrix_i, cam_matrix_j, cam_matrix_k, cam_matrix_l],
                        [cam_matrix_m, cam_matrix_n, cam_matrix_o, cam_matrix_p]]

            print(orbDegrees)
            orbDegrees=5
            print(cam_mat4)
            #         
            rot_mat4 = [[m.cos(m.radians((orbDegrees/animationFrames)*(currentFrame-1))), m.sin(m.radians((orbDegrees/animationFrames)*(currentFrame-1))), 0, 0],
                        [-m.sin(m.radians((orbDegrees/animationFrames)*(currentFrame-1))), m.cos(m.radians((orbDegrees/animationFrames)*(currentFrame-1))), 0, 0],
                        [0, 0, 1, 0],
                        [0, 0, 0, 1]]
            print(rot_mat4)

            for i in range(len(cam_mat4)):
                for j in range(len(rot_mat4[0])):
                    for k in range(len(rot_mat4)):
                        result_mat4[i][j] += cam_mat4[i][k] * rot_mat4[k][j]

            print('cam transform',result_mat4)

            bella_mat4 = "mat4( "
            for each in result_mat4:
                for col in each:
                    bella_mat4 += str(col)+" "
            bella_mat4 += " )"

        #instances_mat4 = "mat4f["+str(currentFrame)+"]{ "
        #for each in range(1,currentFrame+1):
        #    random.seed(each)
        #    random_angle = random.randint(1,360)
        #    random_scale = random.uniform(0.25,1.25)
        #    random_height = random.uniform(0,15)
        #    instance_result_mat4 = [[ 0,0,0,0],
        #        [0,0,0,0],
        #        [0,0,0,0],
        #        [0,0,0,0]]
        #    instance_scale_mat4 = [[ random_scale,0,0,0],
        #        [0,random_scale,0,0],
        #        [0,0,random_scale,0],
        #        [0,0,random_height,1]]
        #    rot_mat4 = [[m.cos(m.radians(random_angle)), m.sin(m.radians(random_angle)), 0, 0],
        #        [-m.sin(m.radians(random_angle)), m.cos(m.radians(random_angle)), 0, 0],
        #        [0, 0, 1, 0],
        #        [0, 0, 0, 1]]
        #    for i in range(len(instance_scale_mat4)):
        #        for j in range(len(rot_mat4[0])):
        #            for k in range(len(rot_mat4)):
        #                instance_result_mat4[i][j] += instance_scale_mat4[i][k] * rot_mat4[k][j]


        #    for i in instance_result_mat4:
        #        for col in i:
        #            instances_mat4 += str(col)+" "
        #instances_mat4 += " }"

        #print(instances_mat4)

        sceneFilePathlib = Path(sceneFile)
        sceneFileStem = sceneFilePathlib.stem
        sceneFileSuffix = sceneFilePathlib.suffix
        # [ ] Had issue with .bsz res directory failing creation by bella_cli
        # created /tmp/res manually and it worked
        tempPath = Path(PathUtils.GetSystemTempPath())

        if sceneFileSuffix == ".bsz":
            # Make a local copy of the sceneFile when rendering a .bsz to prevent unzip clashes with multiple machines
            # [ ] maybe always make a local copy to limit network traffic
            # [ ] need to figure out how to clean up temp directory postjob
            tempSceneFile = str(tempPath / sceneFilePathlib.name)
            shutil.copy(sceneFile, tempSceneFile)
            arguments = " -i:%s" % tempSceneFile
        else:
            arguments = " -i:%s" % sceneFile

        arguments += " -pf:\"beautyPass.overridePath=null;\""

        if outputExt == ".png" or outputExt == "default":
            outputExt = "" # [ ] HACK, parseFragment has no method to unset .outputExt properly ( like null )  
        arguments += " -pf:\"beautyPass.outputExt=\\\"%s\\\";\"" % outputExt

        #if floatAttributeName == "":
        if useOrbit or useFreeformA or useFreeformB:
           renderFramePadded = StringUtils.ToZeroPaddedString( self.GetStartFrame(), 5, False )
           paddedStem = (str(sceneFileStem)+renderFramePadded)
        else:
           paddedStem = sceneFileStem

        arguments += " -pf:\"beautyPass.outputName=\\\"%s\\\";\"" % paddedStem
        if outputExt == "":
            outputExt = ".png"
        self.outputName = paddedStem + outputExt

        # [ ] Warning: sceneFile name used for the outputName, to avoid name clashing by blindly using what is set in bella
        # bella_cli will fail when the outputName has the string default anywhere
        if useFreeformA:
            arguments += " -pf:\"{:s}={:f}f;\"".format(freeformA, freeformAVal)
        if useFreeformB:
            arguments += " -pf:\"{:s}={:f}f;\"".format(freeformB, freeformBVal)

        if not targetNoise == "":
            arguments += " -pf:\"beautyPass.targetNoise=%su;\"" % targetNoise
        if not useGpu == "":
            arguments += " -pf:\"settings.useGpu=true;\"" 
        if not timeLimit == "":
            arguments += " -pf:\"beautyPass.timeLimit=%sf;\""  % timeLimit
        if not denoiseName == "":
            arguments += " -pf:\"beautyPass.denoise=true; beautyPass.denoiseOutputName=\\\"%s\\\";\"" % denoiseName
        arguments += " -pf:\"settings.threads=0;\"" 
        if useOrbit:
            arguments += " -pf:\"camera_xform.steps[0].xform=%s;\"" % bella_mat4
        
        #arguments += " -pf:\"instancer.steps[0].instances=%s;\"" % instances_mat4

        arguments += " -od:\"%s\"" % tempPath
        arguments += " -vo" 
        if not imageWidth == "":
            arguments += " -res:\"%sx%s\"" %(imageWidth,imageHeight)
        return arguments
