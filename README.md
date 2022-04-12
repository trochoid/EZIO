 
# EZIO Documentation
 
 This is my first package Yay!  Intention of EZIO is for a super simple no-brain way to take an object in my program and save it someplace, and of course to load the object back.
 
 This is super alpha code, it's actually a collection of little wrappers I made to work with Codable, so the naming and organization is somewhat inconsistent. 
 
# Codable <-> UserDefaults
 examples...
 
     EZIO.storeObj(obj: myObject, key: kKeyString)
 
     if let obj = EZIO.loadObj(type: MyObject.self, key: kKeyString) { ... }
 
 @AppStorage read/writes to UserDefaults too
 
# Codable <-> external file
 This uses 2 Buttons to wrap the functionality of writing an external file because a sheet has to be shown to ask the user for access permission, and, well, I only know how to do that with a view in hand. Anyways if the user grants permission then a security bookmark is stored in UserDefaults so they only have to grant access once; or until UserDefaults are erased. 
 
     ButtonSave<MyObject>("save obj", fileName: kFileName) {
         //prepare myObject for saving
         return myObject
     }
 
     ButtonLoad("ButtonLoad", fileName: kFileName, type: MyObject.self) { obj in
         //use obj
     }
 
 
 # String,UIImage,UIColor,URL <-> UIPasteboard
 
 

