import Foundation
import CoreMediaIO

@_cdecl("VirtualCameraSampleMain")
func VirtualCameraSampleMain(allocator: CFAllocator, requestedTypeUUID: CFUUID) -> CMIOHardwarePlugInRef {
    return pluginRef
}
