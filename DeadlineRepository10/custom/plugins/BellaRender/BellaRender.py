#!/usr/bin/env python3
import shutil
from Deadline.Plugins import *
from Deadline.Scripting import FileUtils, SystemUtils, RepositoryUtils, FileUtils, PathUtils, FrameUtils, StringUtils
from System.Diagnostics import *
from pathlib import Path
import shutil
#import numpy as np
import math as m
import random
import sys

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
    def __init__(self):
        """setup Deadline callbacks"""
        if sys.version_info.major == 3:
            super().__init__()
        self.InitializeProcessCallback += self.InitializeProcess
        self.PreRenderTasksCallback += self.PreRenderTasks
        self.RenderExecutableCallback += self.RenderExecutable
        self.RenderArgumentCallback += self.RenderArgument

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
        self.sceneFile = self.GetPluginInfoEntry( "sceneFile" ).strip()
        self.sceneFile = RepositoryUtils.CheckPathMapping( self.sceneFile )
        
        sceneFileFramePadded = FrameUtils.GetFrameStringFromFilename( self.sceneFile )
        paddingSize = len( sceneFileFramePadded )
        #print('userFramePadded', sceneFileFramePadded, 'paddingSize', paddingSize) 
        if paddingSize > 0:
            renderFramePadded = StringUtils.ToZeroPaddedString( self.GetStartFrame(), paddingSize, False )
            #print('renderFramePadded',renderFramePadded)
            self.sceneFile = FrameUtils.SubstituteFrameNumber( self.sceneFile, renderFramePadded )

    def RenderExecutable(self):
        """Callback to get executable used for rendering"""
        executableList =  self.GetConfigEntry("BellaRenderPluginRenderExecutable")
        # Goes through semi colon separated list of paths in Bella.param
        # Uses default Diffuse Logic install location for Windows, MacOS and Linux Bella CLI
        executable = FileUtils.SearchFileList( executableList )
        executable="/usr/local/bin/bella_cli"
        print (executable, "hello")
        executable="/usr/local/bin/bella_cli" # hardcoded for now
        if( executable == "" ): self.FailRender( "Bella render executable not found in plugin search paths" )
        return executable

    def RenderArgument(self):
        """Callback to get arguments passed to the executable"""
        sceneFile = self.sceneFile
        sceneFile = RepositoryUtils.CheckPathMapping( sceneFile )   # remap path for worker's OS

        # TODO
        sceneFile = sceneFile.replace("/Volumes/oomerfarm/","/mnt/oomerfarm/")

        outputDirectory = self.GetPluginInfoEntry( "outputDirectory" ).strip()  
        outputDirectory = RepositoryUtils.CheckPathMapping( outputDirectory )   
        
        # TODO
        outputDirectory = "/mnt/oomerfarm/bella/renders"

        outputExt = self.GetPluginInfoEntryWithDefault( "outputExt", "").strip()
        imageWidth = self.GetPluginInfoEntryWithDefault( "imageWidth", "").strip()
        imageHeight = self.GetPluginInfoEntryWithDefault( "imageHeight", "").strip()
        targetNoise = self.GetPluginInfoEntryWithDefault( "targetNoise", "").strip()
        useGpu = self.GetPluginInfoEntryWithDefault( "useGpu", "").strip()
        timeLimit = self.GetPluginInfoEntryWithDefault( "timeLimit", "").strip()
        denoiseName = self.GetPluginInfoEntryWithDefault( "denoise", "").strip()
        floatAttributeName = self.GetPluginInfoEntryWithDefault( "floatAttributeName", "").strip()
        print("XXXXXX",self.GetPluginInfoEntryWithDefault( "floatAttributeStart", ""))
        floatAttributeStart = float(self.GetPluginInfoEntryWithDefault( "floatAttributeStart", "").strip())
        floatAttributeEnd = float(self.GetPluginInfoEntryWithDefault( "floatAttributeEnd", "").strip())
        animationFrames = int(self.GetPluginInfoEntryWithDefault( "animationFrames", "").strip())
        animationLinearIncrement = float(self.GetPluginInfoEntryWithDefault( "animationLinearIncrement", "").strip())
        currentFrame = self.GetStartFrame()
        print(floatAttributeName )
        print(floatAttributeStart )
        print(floatAttributeEnd )
        print(animationFrames,animationLinearIncrement )
        print((float(currentFrame-1)*animationLinearIncrement)+floatAttributeStart)
        focalLen = (float(currentFrame-1)*animationLinearIncrement)+floatAttributeStart


        result_mat4 = [[ 0,0,0,0],
                [0,0,0,0],
                [0,0,0,0],
                [0,0,0,0]]

        
        rot_mat4 = [[m.cos(m.radians((5.0/animationFrames)*(currentFrame-1))), m.sin(m.radians((5.0/animationFrames)*(currentFrame-1))), 0, 0],
                    [-m.sin(m.radians((5.0/animationFrames)*(currentFrame-1))), m.cos(m.radians((5.0/animationFrames)*(currentFrame-1))), 0, 0],
                    [0, 0, 1, 0],
                    [0, 0, 0, 1]]

        for i in range(len(cam_mat4)):
            for j in range(len(rot_mat4[0])):
                for k in range(len(rot_mat4)):
                    result_mat4[i][j] += cam_mat4[i][k] * rot_mat4[k][j]

        #np_rot_mat4 = np.array( rot_mat4, dtype='float64')
        #np_newcam_mat4 = np_cam_mat4 @ np_rot_mat4  # transform camera trnasform matrix by multiplying by a rotation matrix
        print('cam transform',result_mat4)

        bella_mat4 = "mat4( "
        for each in result_mat4:
            for col in each:
                bella_mat4 += str(col)+" "
        bella_mat4 += " )"

        instances_mat4 = "mat4f["+str(currentFrame)+"]{ "
        for each in range(1,currentFrame+1):
            random.seed(each)
            random_angle = random.randint(1,360)
            random_scale = random.uniform(0.25,1.25)
            random_height = random.uniform(0,15)
            instance_result_mat4 = [[ 0,0,0,0],
                [0,0,0,0],
                [0,0,0,0],
                [0,0,0,0]]
            instance_scale_mat4 = [[ random_scale,0,0,0],
                [0,random_scale,0,0],
                [0,0,random_scale,0],
                [0,0,random_height,1]]
            rot_mat4 = [[m.cos(m.radians(random_angle)), m.sin(m.radians(random_angle)), 0, 0],
                [-m.sin(m.radians(random_angle)), m.cos(m.radians(random_angle)), 0, 0],
                [0, 0, 1, 0],
                [0, 0, 0, 1]]

            for i in range(len(instance_scale_mat4)):
                for j in range(len(rot_mat4[0])):
                    for k in range(len(rot_mat4)):
                        instance_result_mat4[i][j] += instance_scale_mat4[i][k] * rot_mat4[k][j]


            for i in instance_result_mat4:
                for col in i:
                    instances_mat4 += str(col)+" "
        instances_mat4 += " }"

        print(instances_mat4)


        print("XXX",outputDirectory)
        print("XXX",sceneFile)

        # [ ] do this in PreRenderTasks, needs cross platform testing 
        if SystemUtils.IsRunningOnWindows():
            sceneFile = sceneFile.replace( "/", "\\" )
            outputDirectory = outputDirectory.replace( "/", "\\" )
            if sceneFile.startswith( "\\" ) and not sceneFile.startswith( "\\\\" ):
                sceneFile = "\\" + sceneFile
            if outputDirectory.startswith( "\\" ) and not outputDirectory.startswith( "\\\\" ):
                outputDirectory = "\\" + outputDirectory
        else:
            sceneFile = sceneFile.replace( "\\", "/" )

        sceneFilePathlib = Path(sceneFile)
        sceneFileStem = sceneFilePathlib.stem
        sceneFileSuffix = sceneFilePathlib.suffix
        # [ ] Had issue with .bsz res directory failing creation by bella_cli
        # created /tmp/res manually and it worked
        tempPath = Path(PathUtils.GetSystemTempPath())
        print(tempPath,sceneFileSuffix)

        if sceneFileSuffix == ".bsz":
            # Make a local copy of the sceneFile when rendering a .bsz to prevent unzip clashes with multiple machines
            # [ ] maybe always make a local copy to limit network traffic
            # [ ] need to figure out how to clean up temp directory postjob
            tempSceneFile = str(tempPath / sceneFilePathlib.name)
            shutil.copy(sceneFile, tempSceneFile)
            arguments = " -i:%s" % tempSceneFile
        else:
            arguments = " -i:%s" % sceneFile

        #arguments = " -i:\"%s\"" % sceneFile
        arguments += " -pf:\"beautyPass.overridePath=null;\""

        if outputExt == ".png" or outputExt == "default":
            outputExt = "" # [ ] HACK, parseFragment has no method to unset .outputExt properly ( like null )  
        arguments += " -pf:\"beautyPass.outputExt=\\\"%s\\\";\"" % outputExt

        if floatAttributeName == "":
            arguments += " -pf:\"beautyPass.outputName=\\\"%s\\\";\"" % sceneFileStem
        else:
            renderFramePadded = StringUtils.ToZeroPaddedString( self.GetStartFrame(), 5, False )
            print(str(sceneFileStem)+renderFramePadded)
            arguments += " -pf:\"beautyPass.outputName=\\\"%s\\\";\"" % (str(sceneFileStem)+renderFramePadded)




        # [ ] Warning: sceneFile name used for the outputName, to avoid name clashing by blindly using what is set in bella
        # bella_cli will fail when the outputName has the string default anywhere
        if not floatAttributeName == "":
        #   arguments += " -pf:\"%s.steps[0].focalLen=%ff;\"" % floatAttributeName % focalLen
            arguments += " -pf:\"{:s}={:f}f;\"".format(floatAttributeName, focalLen)

        if not targetNoise == "":
            arguments += " -pf:\"beautyPass.targetNoise=%su;\"" % targetNoise
        if not useGpu == "":
            arguments += " -pf:\"settings.useGpu=true;\"" 
        if not timeLimit == "":
            arguments += " -pf:\"beautyPass.timeLimit=%sf;\""  % timeLimit
        if not denoiseName == "":
            arguments += " -pf:\"beautyPass.denoise=true; beautyPass.denoiseOutputName=\\\"%s\\\";\"" % denoiseName
        arguments += " -pf:\"settings.threads=0;\"" 
        arguments += " -pf:\"camera_xform.steps[0].xform=%s;\"" % bella_mat4
        
        arguments += " -pf:\"instancer.steps[0].instances=%s;\"" % instances_mat4

        arguments += " -od:\"%s\"" % outputDirectory
        arguments += " -vo" 
        if not imageWidth == "":
            arguments += " -res:\"%sx%s\"" %(imageWidth,imageHeight)
        return arguments
