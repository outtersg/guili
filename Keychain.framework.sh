#!/bin/bash

. `dirname "$0"`/util.sh

cd /tmp
tar xjf `obtenir http://switch.dl.sourceforge.net/sourceforge/keychain/KeychainFramework.tar.bz2`
mv Keychain\ Framework* kcf # Sinon ça contient des caractères bizarres qui perturbent libtool.
cd kcf

filtrer Keychain.pbproj/project.pbxproj sed -e '/^[ 	]*INSTALL_PATH[ 	]*=/s:=.*$:= /tmp/;:' -e '/^[ 	]*productInstallPath[ 	]*=/s:=.*$:= /tmp/;:'

false && patch -p1 << TERMINE
diff -ru Keychain Framework.original/Keychain.h Keychain Framework/Keychain.h
--- Keychain Framework.original/Keychain.h	Mon Oct  6 14:18:27 2003
+++ Keychain Framework/Keychain.h	Sat Jul  3 09:42:20 2004
@@ -266,6 +266,14 @@
 - (void)addItem:(KeychainItem*)item;
 //- (void)importCertificateBundle:(CertificateBundle*)bundle;
 
+/*! @method addNewItemWithClass:access:
+    @abstract Adds a new KeychainItem to the receiver, with given initial parameters.
+    @discussion This method adds a new empty KeychainItem given to the receiver. It is primarily designed to customize authorized applications access. The resulting item has then to be filled with KeychainItem modifiers.
+    @param itemClass The class of the news item.
+    @param initialAccess The customized access to the item. Pass nil for giving access to the current application. */
+
+- (KeychainItem*)addNewItemWithClass:(SecItemClass)itemClass access:(Access*)initialAccess;
+
 /*! @method addCertificate:privateKey:withName:
     @abstract Creates a new identity in the receiver for the given certificate and private key.
     @discussion An identity is represented by a private key and a certificate in which the subject's public key is paired to the given private key.  An identity can be used to represent someone or some entity.  The certificate can be a self-signed certificate, or signed by some other authority.
diff -ru Keychain Framework.original/Keychain.m Keychain Framework/Keychain.m
--- Keychain Framework.original/Keychain.m	Mon Sep 29 06:53:32 2003
+++ Keychain Framework/Keychain.m	Sat Jul  3 09:17:04 2004
@@ -428,6 +428,13 @@
     }
 }
 
+- (KeychainItem*)addNewItemWithClass:(SecItemClass)itemClass access:(Access*)initialAccess {
+	SecKeychainItemRef keychainItem;
+	SecKeychainAttributeList attributes = { 0, nil };
+	error = SecKeychainItemCreateFromContent(itemClass, &attributes, 0, nil, keychain, [initialAccess accessRef], &keychainItem);
+	return error ? nil : [KeychainItem keychainItemWithKeychainItemRef:keychainItem];
+}
+
 /*- (void)importCertificateBundle:(CertificateBundle*)bundle {
     error = SecCertificateBundleImport(keychain, [bundle bundle], [bundle type], [bundle encoding], nil);
 }*/
TERMINE
false && patch -p1 << TERMINE
diff -ru Keychain Framework.original/Access.h Keychain Framework/Access.h
--- Keychain Framework.original/Access.h	Thu Jun 26 06:32:08 2003
+++ Keychain Framework/Access.h	Sat Jul  3 14:46:06 2004
@@ -36,6 +36,13 @@
 
 + (Access*)accessWithName:(NSString*)name;
 
+/*! @method accessEmptyWithName:
+    @abstract Creates and returns an Access with the name provided, and no authorization, even for the calling application.
+    @param name The name of the new Access instance.
+    @result Returns the new instance, or nil if an error occurs. */
+
++ (Access*)accessEmptyWithName:(NSString*)name;
+
 /*! @method accessWithAccessRef:
     @abstract Creates and returns an Access instance derived from a SecAccessRef.
     @discussion Creates and returns an Access instance derived [and linked to] the SecAccessRef provided.  Changes to the SecAccessRef will reflect in the returned instance, and vice versa.  Note that instances created from SecAccessRef's are cached, meaning successive calls to this method with the same SecAccessRef will return the same unique instance.
@@ -51,6 +58,14 @@
     @result Returns the created instance.  If an error occurs, the receiver is released and nil is returned. */
 
 - (Access*)initWithName:(NSString*)name;
+
+/*! @method initEmptyWithName:
+    @abstract Initializes an Access instance with the name provided; no ACL is defined in it.
+    @discussion Even the KeychainItem creating application will require a password to modify the Item.
+    @param name The name to be given to the Access instance.
+    @result Returns the created instance.  If an error occurs, the receiver is released and nil is returned. */
+
+- (Access*)initEmptyWithName:(NSString*)name;
 
 /*! @method initWithAccessRef:
     @abstract Initializes an Access instance around the SecAccessRef provided
diff -ru Keychain Framework.original/Access.m Keychain Framework/Access.m
--- Keychain Framework.original/Access.m	Sat Jul 19 13:06:41 2003
+++ Keychain Framework/Access.m	Sat Jul  3 14:53:49 2004
@@ -20,6 +20,10 @@
     return [[[[self class] alloc] initWithName:name] autorelease];
 }
 
++ (Access*)accessEmptyWithName:(NSString*)name {
+    return [[[[self class] alloc] initEmptyWithName:name] autorelease];
+}
+
 + (Access*)accessWithAccessRef:(SecAccessRef)acc {
     return [[[[self class] alloc] initWithAccessRef:acc] autorelease];
 }
@@ -38,6 +42,20 @@
     }
 }
 
+- (Access*)initEmptyWithName:(NSString*)name {
+    error = SecAccessCreate((CFStringRef)name, (CFArrayRef)[NSArray array], &access);
+
+    if (error == 0) {
+        self = [super init];
+        
+        return self;
+    } else {
+        [self release];
+        
+        return nil;
+    }
+}
+
 - (Access*)initWithAccessRef:(SecAccessRef)acc {
     Access *existingObject;
     
TERMINE
false && patch -p1 << TERMINE
diff -ru Keychain Framework.original/Access.m Keychain Framework/Access.m
--- Keychain Framework.original/Access.m	Sat Jul 19 13:06:41 2003
+++ Keychain Framework/Access.m	Sat Jul  3 14:53:49 2004
@@ -65,11 +83,23 @@
 
 - (NSArray*)accessControlLists {
     CFArrayRef results;
+    NSMutableArray *finalResults;
+    NSEnumerator *enumerator;
+    SecACLRef current;
 
     error = SecAccessCopyACLList(access, &results);
 
     if (error == 0) {
-        return [(NSArray*)results autorelease];
+        enumerator = [(NSArray*)results objectEnumerator];
+        finalResults = [NSMutableArray arrayWithCapacity:[(NSArray*)results count]];
+
+        while (current = (SecACLRef)[enumerator nextObject]) {
+            [finalResults addObject:[AccessControlList accessControlListWithACLRef:current]];
+        }
+
+        CFRelease(results);
+        
+        return [finalResults autorelease];
     } else {
         return nil;
     }
TERMINE
false && patch -p1 << TERMINE
diff -ru Keychain Framework.original/AccessControlList.m Keychain Framework/AccessControlList.m
--- Keychain Framework.original/AccessControlList.m	Sat Jul 19 13:07:24 2003
+++ Keychain Framework/AccessControlList.m	Sat Jul  3 14:31:43 2004
@@ -93,8 +93,8 @@
     if (error == 0) {
         error = SecACLSetSimpleContents(ACL, (CFArrayRef)applications, desc, &woop);
 
-        CFRelease(appList);
-        CFRelease(desc);
+        if(appList) CFRelease(appList);
+        if(desc) CFRelease(desc);
     }
 }
 
@@ -164,9 +164,10 @@
     if (error != 0) {
         return nil;
     } else {
-        CFRelease(appList);
+		if(appList)
+			CFRelease(appList);
         
-        return [[[NSString alloc] initWithData:[(NSData*)desc autorelease]] autorelease];
+        return [(NSString *)desc autorelease];
     }
 }
 
TERMINE

xcodebuild
sudo cp -r /tmp/kcf /Library/Frameworks/
dest=/tmp/kcf/build/Default/Keychain.framework
[ -d "$dest" ] || dest=/Users/gui/tmp/obj/Default/Keychain.framework
sudo cp -r "$dest" /Library/Frameworks/
