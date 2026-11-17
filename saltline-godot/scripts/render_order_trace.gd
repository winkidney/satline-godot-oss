extends RefCounted
var mutex=Mutex.new()
var frame=0
var events=[]
func begin(value:int)->void:
 mutex.lock();frame=value;events=[];mutex.unlock()
func record(label:String)->void:
 mutex.lock();events.append(label);mutex.unlock()
func snapshot()->Dictionary:
 mutex.lock();var result={"frame":frame,"events":events.duplicate()};mutex.unlock();return result
