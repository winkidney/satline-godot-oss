extends RefCounted

static var reduced=false

static func refresh(platform_value:int)->void:
 reduced=platform_value==1

static func duration(seconds:float)->float:
 return .00001 if reduced else seconds
