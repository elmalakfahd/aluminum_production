import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'models.dart';
import 'die_template_model.dart';

// ============================================================
// ✅ Abstract Service Interface
// ============================================================
abstract class AbstractFirebaseService {
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<String> getFactoryId();
  Future<void> setFactoryId(String factoryId);
  Future<String> saveShift(ShiftModel shift);
  Future<void> updateShift(ShiftModel shift);
  Stream<List<ShiftModel>> streamAllActiveShifts(String factoryId);
  Future<List<ShiftModel>> getAllActiveShifts(String factoryId);
  Future<List<ShiftModel>> getAllShifts(String factoryId);
  Future<void> deleteShift(String factoryId, String id);
  Future<ShiftModel?> getLocalShift();
  Future<String> getCurrentUserUid();
  Future<UserModel?> getCurrentUserData();
  Future<void> saveUser(UserModel user);
  Future<List<UserModel>> getAllUsers(String factoryId);
  Future<List<UserModel>> getAllUsersForFactories(List<String> factoryIds);
  Future<UserModel?> getUser(String uid);
  Future<void> updateUser(UserModel user);
  Future<void> deleteUser(String uid);
  Future<bool> validateFactoryId(String factoryId);
  Future<void> refreshUserPermissions();
  Future<List<FactoryModel>> getFactoriesForOwner(String ownerId);
  Future<List<FactoryModel>> getFactoriesForManager(String managerId);
  Future<FactoryModel?> getFactory(String factoryId);
  Future<void> createFactory(FactoryModel factory);
  Future<void> updateFactory(FactoryModel factory);
  Future<void> deleteFactory(String factoryId);
  Future<void> updateUserFactory(String uid, String newFactoryId, String newFactoryName);
  Future<void> saveDraftDie(String factoryId, String shiftId, DieModel draftDie);
  Future<DieModel?> getDraftDie(String factoryId, String shiftId);
  Future<void> deleteDraftDie(String factoryId, String shiftId);
  Future<List<PressModel>> getPresses(String factoryId);
  Future<void> savePress(String factoryId, PressModel press);
  Future<void> deletePress(String factoryId, String pressId);
  Future<bool> isEmailRegisteredInAnyFactory(String email);
  Future<List<FactoryModel>> getAllFactories();
  Future<ShiftModel?> getShiftById(String factoryId, String shiftId);
  Stream<DieModel?> streamDraftDie(String factoryId, String shiftId);
  
  Future<List<FurnaceModel>> getFurnaces(String factoryId);
  Future<void> saveFurnace(String factoryId, FurnaceModel furnace);
  Future<void> deleteFurnace(String factoryId, String furnaceId);
  Future<FurnaceModel?> getFurnace(String factoryId, String furnaceId);

  // دوال القوالب المسجلة (Die Templates)
  Future<List<DieTemplate>> getDieTemplates(String factoryId);
  Future<void> saveDieTemplate(String factoryId, DieTemplate die);
  Future<void> deleteDieTemplate(String factoryId, String dieId);
  Future<DieTemplate?> getDieTemplateByCode(String factoryId, String code);
  Future<List<DieTemplate>> searchDieTemplates(String factoryId, String query);
  Future<List<DieTemplate>> getDieTemplatesByBaseCode(String factoryId, String baseCode);
  
  // ✅ دوال رصيد الخامة حسب القطر
  Future<List<MaterialStockModel>> getMaterialStocks(String factoryId);
  Future<void> saveMaterialStock(String factoryId, MaterialStockModel stock);
  Future<void> deleteMaterialStock(String factoryId, String stockId);
}

// ============================================================
// ✅ Firebase Service Implementation
// ============================================================
class FirebaseServiceImpl implements AbstractFirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String? _currentFactoryId;
  UserModel? _cachedUser;

  String _cleanFactoryId(String factoryId) {
    if (factoryId.isEmpty) return factoryId;
    String cleaned = factoryId.replaceFirst(RegExp(r'^[0-9]+'), '');
    if (cleaned.isEmpty) return factoryId;
    return cleaned;
  }

  @override
  Future<String> getCurrentUserUid() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    return user.uid;
  }

  @override
  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    if (_cachedUser != null) return _cachedUser;
    
    try {
      String factoryId = await getFactoryId();
      if (factoryId.isEmpty) {
        factoryId = 'default_factory';
        await setFactoryId(factoryId);
      }
      
      factoryId = _cleanFactoryId(factoryId.trim());
      
      if (factoryId.isEmpty) {
        factoryId = 'default_factory';
      }
      
      print('📥 جلب بيانات المستخدم الحالي من المصنع: "$factoryId"');
      
      final allUsers = await getAllUsers(factoryId);
      
      UserModel? foundUser;
      for (var u in allUsers) {
        if (u.email.toLowerCase() == user.email!.toLowerCase()) {
          foundUser = u;
          break;
        }
      }
      
      if (foundUser != null) {
        if (foundUser.isOwner) {
          final allFactories = await getFactoriesForOwner(foundUser.uid);
          final updatedUser = UserModel(
            uid: foundUser.uid,
            email: foundUser.email,
            name: foundUser.name,
            role: foundUser.role,
            factoryId: foundUser.factoryId,
            factoryName: foundUser.factoryName,
            factories: allFactories.map((f) => f.id).toList(),
            managedFactories: foundUser.managedFactories,
            canEndShift: foundUser.canEndShift,
            assignedPressId: foundUser.assignedPressId,
            department: foundUser.department,
            modules: foundUser.modules,
          );
          _cachedUser = updatedUser;
          return _cachedUser;
        }
        
        if (foundUser.isManager) {
          final allFactories = await getFactoriesForManager(foundUser.uid);
          final updatedUser = UserModel(
            uid: foundUser.uid,
            email: foundUser.email,
            name: foundUser.name,
            role: foundUser.role,
            factoryId: foundUser.factoryId,
            factoryName: foundUser.factoryName,
            factories: foundUser.factories,
            managedFactories: allFactories.map((f) => f.id).toList(),
            canEndShift: foundUser.canEndShift,
            assignedPressId: foundUser.assignedPressId,
            department: foundUser.department,
            modules: foundUser.modules,
          );
          _cachedUser = updatedUser;
          return _cachedUser;
        }
        
        _cachedUser = foundUser;
        return _cachedUser;
      }
      
      print('📝 البحث عن المستخدم في جميع المصانع...');
      final allFactories = await getAllFactories();
      for (var factory in allFactories) {
        final users = await getAllUsers(factory.id);
        for (var u in users) {
          if (u.email.toLowerCase() == user.email!.toLowerCase()) {
            if (u.isOwner) {
              final ownerFactories = await getFactoriesForOwner(u.uid);
              final updatedUser = UserModel(
                uid: u.uid,
                email: u.email,
                name: u.name,
                role: u.role,
                factoryId: u.factoryId,
                factoryName: u.factoryName,
                factories: ownerFactories.map((f) => f.id).toList(),
                managedFactories: u.managedFactories,
                canEndShift: u.canEndShift,
                assignedPressId: u.assignedPressId,
              );
              _cachedUser = updatedUser;
              return _cachedUser;
            }
            
            if (u.isManager) {
              final managerFactories = await getFactoriesForManager(u.uid);
              final updatedUser = UserModel(
                uid: u.uid,
                email: u.email,
                name: u.name,
                role: u.role,
                factoryId: u.factoryId,
                factoryName: u.factoryName,
                factories: u.factories,
                managedFactories: managerFactories.map((f) => f.id).toList(),
                canEndShift: u.canEndShift,
                assignedPressId: u.assignedPressId,
              );
              _cachedUser = updatedUser;
              return _cachedUser;
            }
          }
        }
      }
      
      print('📝 المستخدم غير موجود في أي مصنع، سيتم إنشاء حساب جديد');
      
      await _ensureFactoryExists(factoryId, user.uid, user.displayName ?? user.email?.split('@').first ?? 'مستخدم', user.email ?? '');
      
      String role = 'operator';
      if (user.email == 'elmalakfahd1@gmail.com') {
        role = 'developer';
      }
      
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? user.email?.split('@').first ?? 'مستخدم',
        role: role,
        factoryId: factoryId,
        factoryName: factoryId,
        factories: role == 'owner' ? [factoryId] : [],
        managedFactories: [],
        canEndShift: role == 'developer',
        assignedPressId: null,
      );
      
      await saveUser(newUser);
      _cachedUser = newUser;
      
      Fluttertoast.showToast(
        msg: '✅ تم تفعيل حسابك تلقائياً. مرحباً بك ${newUser.name}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
      
      print('✅ تم إنشاء مستخدم جديد: ${newUser.name}');
      return newUser;
      
    } catch (e) {
      print('❌ خطأ في جلب بيانات المستخدم: $e');
      return null;
    }
  }

  @override
  Future<List<FactoryModel>> getAllFactories() async {
    final List<FactoryModel> factories = [];
    try {
      final snapshot = await _database.child('factories').once();
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> jsonMap = {};
            (value as Map<dynamic, dynamic>).forEach((k, v) {
              jsonMap[k.toString()] = v;
            });
            factories.add(FactoryModel.fromJson(key.toString().trim(), jsonMap));
          }
        });
      }
    } catch (e) {
      print('خطأ في جلب جميع المصانع: $e');
    }
    return factories;
  }

  @override
  Future<bool> isEmailRegisteredInAnyFactory(String email) async {
    try {
      final allFactories = await getAllFactories();
      for (var factory in allFactories) {
        final users = await getAllUsers(factory.id);
        for (var user in users) {
          if (user.email.toLowerCase() == email.toLowerCase()) {
            print('⚠️ البريد موجود في مصنع: ${factory.name}');
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('خطأ في التحقق من البريد: $e');
      return false;
    }
  }

  Future<void> _ensureFactoryExists(String factoryId, String ownerId, String ownerName, String ownerEmail) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      final snapshot = await _database.child('factories').child(cleanFactoryId).once();
      if (snapshot.snapshot.value == null) {
        print('🏭 إنشاء مصنع جديد: $cleanFactoryId');
        await _database.child('factories').child(cleanFactoryId).set({
          'name': cleanFactoryId,
          'ownerId': ownerId,
          'ownerEmail': ownerEmail,
          'ownerName': ownerName,
          'managers': [],
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('⚠️ خطأ في التحقق من وجود المصنع: $e');
    }
  }

  @override
  Future<void> refreshUserPermissions() async {
    _cachedUser = null;
    await getCurrentUserData();
  }

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _cachedUser = null;
      await getCurrentUserData();
    } on FirebaseAuthException catch (e) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _cachedUser = null;
  }

  @override
  Future<String> getFactoryId() async {
    if (_currentFactoryId != null && _currentFactoryId!.isNotEmpty) {
      final cleaned = _cleanFactoryId(_currentFactoryId!);
      if (cleaned.isNotEmpty && cleaned != _currentFactoryId) {
        _currentFactoryId = cleaned;
        await setFactoryId(_currentFactoryId!);
        print('🧹 تم تنظيف معرف المصنع إلى: "$_currentFactoryId"');
      }
      return _currentFactoryId!;
    }
    
    final user = _auth.currentUser;
    if (user == null) return 'default_factory';
    
    try {
      final snapshot = await _database.child('users').child(user.uid).child('factoryId').once();
      if (snapshot.snapshot.value != null) {
        final value = snapshot.snapshot.value.toString().trim();
        if (value.isNotEmpty) {
          _currentFactoryId = _cleanFactoryId(value);
          print('📥 تم جلب معرف المصنع: "$_currentFactoryId"');
          return _currentFactoryId!;
        }
      }
      
      try {
        final factoriesSnapshot = await _database.child('factories').once();
        if (factoriesSnapshot.snapshot.value != null) {
          final data = factoriesSnapshot.snapshot.value as Map<dynamic, dynamic>;
          for (var entry in data.entries) {
            final factoryData = entry.value as Map<dynamic, dynamic>;
            final factoryId = _cleanFactoryId(entry.key.toString().trim());
            
            if (factoryData['ownerId'] == user.uid) {
              _currentFactoryId = factoryId;
              await setFactoryId(_currentFactoryId!);
              return _currentFactoryId!;
            }
            
            final managers = factoryData['managers'] as List? ?? [];
            if (managers.contains(user.uid)) {
              _currentFactoryId = factoryId;
              await setFactoryId(_currentFactoryId!);
              return _currentFactoryId!;
            }
          }
        }
      } catch (e) {
        print('خطأ في البحث عن مصانع المستخدم: $e');
      }
      
      _currentFactoryId = 'default_factory';
      await setFactoryId(_currentFactoryId!);
      return _currentFactoryId!;
      
    } catch (e) {
      print('خطأ في جلب معرف المصنع: $e');
      _currentFactoryId = 'default_factory';
      return _currentFactoryId!;
    }
  }

  @override
  Future<void> setFactoryId(String factoryId) async {
    _currentFactoryId = _cleanFactoryId(factoryId.trim());
    final user = _auth.currentUser;
    if (user != null) {
      await _database.child('users').child(user.uid).child('factoryId').set(_currentFactoryId);
      
      final existingUser = await getUser(user.uid);
      if (existingUser != null) {
        final updatedUser = UserModel(
          uid: existingUser.uid,
          email: existingUser.email,
          name: existingUser.name,
          role: existingUser.role,
          factoryId: _currentFactoryId!,
          factoryName: existingUser.factoryName,
          factories: existingUser.factories,
          managedFactories: existingUser.managedFactories,
          canEndShift: existingUser.canEndShift,
          assignedPressId: existingUser.assignedPressId,
        );
        await saveUser(updatedUser);
        _cachedUser = null;
      }
    }
  }

  @override
  Future<bool> validateFactoryId(String factoryId) async {
    try {
      if (factoryId.isEmpty) return false;
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      final snapshot = await _database.child('factories').child(cleanFactoryId).once();
      return snapshot.snapshot.value != null;
    } catch (e) {
      print('خطأ في التحقق من المصنع: $e');
      return false;
    }
  }

  @override
  Future<List<FactoryModel>> getFactoriesForOwner(String ownerId) async {
    final List<FactoryModel> factories = [];
    try {
      final snapshot = await _database.child('factories').once();
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> jsonMap = {};
            (value as Map<dynamic, dynamic>).forEach((k, v) {
              jsonMap[k.toString()] = v;
            });
            if (jsonMap['ownerId'] == ownerId) {
              factories.add(FactoryModel.fromJson(key.toString().trim(), jsonMap));
            }
          }
        });
      }
    } catch (e) {
      print('خطأ في جلب المصانع للمالك: $e');
    }
    return factories;
  }

  @override
  Future<List<FactoryModel>> getFactoriesForManager(String managerId) async {
    final List<FactoryModel> factories = [];
    try {
      final snapshot = await _database.child('factories').once();
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final Map<String, dynamic> jsonMap = {};
            (value as Map<dynamic, dynamic>).forEach((k, v) {
              jsonMap[k.toString()] = v;
            });
            final managers = jsonMap['managers'] as List? ?? [];
            if (managers.contains(managerId)) {
              factories.add(FactoryModel.fromJson(key.toString().trim(), jsonMap));
            }
          }
        });
      }
    } catch (e) {
      print('خطأ في جلب المصانع للمدير: $e');
    }
    return factories;
  }

  @override
  Future<FactoryModel?> getFactory(String factoryId) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      final snapshot = await _database.child('factories').child(cleanFactoryId).once();
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> jsonMap = {};
        (data as Map<dynamic, dynamic>).forEach((k, v) {
          jsonMap[k.toString()] = v;
        });
        return FactoryModel.fromJson(cleanFactoryId, jsonMap);
      }
    } catch (e) {
      print('خطأ في جلب المصنع: $e');
    }
    return null;
  }

  @override
  Future<void> createFactory(FactoryModel factory) async {
    await _database.child('factories').child(factory.id.trim()).set(factory.toJson());
  }

  @override
  Future<void> updateFactory(FactoryModel factory) async {
    await _database.child('factories').child(factory.id.trim()).update(factory.toJson());
  }

  @override
  Future<void> deleteFactory(String factoryId) async {
    await _database.child('factories').child(factoryId.trim()).remove();
  }

  @override
  Future<void> saveUser(UserModel user) async {
    try {
      String factoryId = _cleanFactoryId(user.factoryId.trim());
      if (factoryId.isEmpty) {
        factoryId = await getFactoryId();
      }
      if (factoryId.isEmpty) {
        factoryId = 'default_factory';
      }
      
      await _ensureFactoryExists(factoryId, user.uid, user.name, user.email);
      
      await _database
          .child('factories')
          .child(factoryId)
          .child('users')
          .child(user.uid)
          .set(user.toJson());
      
      await _database.child('users').child(user.uid).child('factoryId').set(factoryId);
      
      _cachedUser = user;
      _currentFactoryId = factoryId;
      
      print('✅ تم حفظ المستخدم: ${user.name}');
      
    } catch (e) {
      print('❌ خطأ في حفظ المستخدم: $e');
      rethrow;
    }
  }

  @override
  Future<List<UserModel>> getAllUsers(String factoryId) async {
    final List<UserModel> users = [];
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في getAllUsers');
        return users;
      }
      
      print('📥 جلب المستخدمين من المصنع: "$cleanFactoryId"');
      
      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('users')
          .once();
      
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final Map<String, dynamic> jsonMap = {};
              (value as Map<dynamic, dynamic>).forEach((k, v) {
                jsonMap[k.toString()] = v;
              });
              final user = UserModel.fromJson(jsonMap);
              users.add(user);
              print('✅ تم تحميل المستخدم: ${user.name}');
            } catch (e) {
              print('⚠️ خطأ في تحويل المستخدم: $e');
            }
          }
        });
      } else {
        print('⚠️ لا يوجد مستخدمين في المصنع: "$cleanFactoryId"');
      }
      
      print('✅ تم تحميل ${users.length} مستخدم');
      
    } catch (e) {
      print('❌ خطأ في جلب المستخدمين: $e');
    }
    return users;
  }

  @override
  Future<List<UserModel>> getAllUsersForFactories(List<String> factoryIds) async {
    final List<UserModel> allUsers = [];
    for (var factoryId in factoryIds) {
      final users = await getAllUsers(factoryId);
      allUsers.addAll(users);
    }
    return allUsers;
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    try {
      if (uid.isEmpty) {
        print('⚠️ UID فارغ في getUser');
        return null;
      }
      
      final factorySnapshot = await _database
          .child('users')
          .child(uid)
          .child('factoryId')
          .once();
      final rawFactoryId = factorySnapshot.snapshot.value?.toString().trim() ?? '';
      if (rawFactoryId.isEmpty) {
        print('⚠️ لا يوجد فهرس مصنع لهذا المستخدم: $uid');
        return null;
      }
      
      final cleanFactoryId = _cleanFactoryId(rawFactoryId);
      
      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('users')
          .child(uid)
          .once();
      
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> jsonMap = {};
        data.forEach((k, v) {
          jsonMap[k.toString()] = v;
        });
        return UserModel.fromJson(jsonMap);
      }
    } catch (e) {
      print('خطأ في جلب المستخدم: $e');
    }
    return null;
  }

  @override
  Future<void> updateUser(UserModel user) async {
    try {
      String cleanFactoryId = _cleanFactoryId(user.factoryId.trim());
      
      if (cleanFactoryId.isEmpty) {
        final factorySnapshot = await _database
            .child('users')
            .child(user.uid)
            .child('factoryId')
            .once();
        cleanFactoryId = _cleanFactoryId(
          factorySnapshot.snapshot.value?.toString().trim() ?? '',
        );
      }
      
      if (cleanFactoryId.isEmpty) {
        cleanFactoryId = 'default_factory';
      }
      
      final existingSnapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('users')
          .child(user.uid)
          .once();
      
      if (existingSnapshot.snapshot.value == null) {
        print('⚠️ المستخدم غير موجود في مصنعه المسجل، سيتم حفظه بدلاً من تحديثه');
        await saveUser(user);
        return;
      }
      
      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('users')
          .child(user.uid)
          .update(user.toJson());
      
      if (_cachedUser != null && _cachedUser!.uid == user.uid) {
        _cachedUser = user;
      }
      
      print('✅ تم تحديث المستخدم: ${user.name}');
    } catch (e) {
      print('❌ خطأ في تحديث المستخدم: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateUserFactory(String uid, String newFactoryId, String newFactoryName) async {
    try {
      final cleanNewFactoryId = _cleanFactoryId(newFactoryId.trim());
      if (cleanNewFactoryId.isEmpty) {
        throw Exception('معرف المصنع لا يمكن أن يكون فارغاً');
      }
      
      final user = await getUser(uid);
      if (user == null) {
        print('⚠️ المستخدم غير موجود');
        return;
      }

      final oldFactoryId = _cleanFactoryId(user.factoryId.trim());
      if (oldFactoryId.isNotEmpty) {
        await _database
            .child('factories')
            .child(oldFactoryId)
            .child('users')
            .child(uid)
            .remove();
        print('🗑️ تم حذف المستخدم من المصنع القديم: "$oldFactoryId"');
      }

      await _ensureFactoryExists(cleanNewFactoryId, user.uid, user.name, user.email);

      final updatedUser = UserModel(
        uid: user.uid,
        email: user.email,
        name: user.name,
        role: user.role,
        factoryId: cleanNewFactoryId,
        factoryName: newFactoryName.isNotEmpty ? newFactoryName.trim() : cleanNewFactoryId,
        factories: user.factories,
        managedFactories: user.managedFactories,
        canEndShift: user.canEndShift,
        assignedPressId: user.assignedPressId,
      );

      await saveUser(updatedUser);

      if (_cachedUser != null && _cachedUser!.uid == uid) {
        _cachedUser = updatedUser;
        _currentFactoryId = cleanNewFactoryId;
      }

      print('✅ تم تحديث مصنع المستخدم إلى: "$cleanNewFactoryId"');
    } catch (e) {
      print('❌ خطأ في تحديث مصنع المستخدم: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteUser(String uid) async {
    try {
      final factoryId = await getFactoryId();
      if (factoryId.isEmpty) {
        print('⚠️ factoryId فارغ في deleteUser');
        return;
      }
      
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      
      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('users')
          .child(uid)
          .remove();
      
      await _database.child('users').child(uid).remove();
      
      if (_cachedUser != null && _cachedUser!.uid == uid) {
        _cachedUser = null;
      }
      
      print('🗑️ تم حذف المستخدم: $uid');
    } catch (e) {
      print('❌ خطأ في حذف المستخدم: $e');
      rethrow;
    }
  }

  // ============================================================
  // ✅ دوال المزامنة اللحظية (Draft Die)
  // ============================================================

  @override
  Future<void> saveDraftDie(String factoryId, String shiftId, DieModel draftDie) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في saveDraftDie');
        return;
      }
      
      final draftRef = _database
          .child('factories')
          .child(cleanFactoryId)
          .child('shifts')
          .child(shiftId)
          .child('draft');
      
      await draftRef.set(draftDie.toJson());
      print('✅ تم حفظ القالب قيد الإدخال في Firebase: ${draftDie.name}');
      
    } catch (e) {
      print('❌ خطأ في حفظ القالب قيد الإدخال: $e');
      rethrow;
    }
  }

  @override
  Future<DieModel?> getDraftDie(String factoryId, String shiftId) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في getDraftDie');
        return null;
      }
      
      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('shifts')
          .child(shiftId)
          .child('draft')
          .once();
      
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> jsonMap = {};
        data.forEach((k, v) {
          jsonMap[k.toString()] = v;
        });
        return DieModel.fromJson('draft', jsonMap);
      }
      
      return null;
      
    } catch (e) {
      print('خطأ في جلب القالب قيد الإدخال: $e');
      return null;
    }
  }

  @override
  Future<void> deleteDraftDie(String factoryId, String shiftId) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في deleteDraftDie');
        return;
      }
      
      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('shifts')
          .child(shiftId)
          .child('draft')
          .remove();
      
      print('🗑️ تم حذف القالب قيد الإدخال');
      
    } catch (e) {
      print('❌ خطأ في حذف القالب قيد الإدخال: $e');
      rethrow;
    }
  }

  @override
  Stream<DieModel?> streamDraftDie(String factoryId, String shiftId) {
    final cleanFactoryId = _cleanFactoryId(factoryId.trim());
    return _database
        .child('factories')
        .child(cleanFactoryId)
        .child('shifts')
        .child(shiftId)
        .child('draft')
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data != null) {
            try {
              final Map<String, dynamic> jsonMap = {};
              (data as Map<dynamic, dynamic>).forEach((k, v) {
                jsonMap[k.toString()] = v;
              });
              return DieModel.fromJson('draft', jsonMap);
            } catch (e) {
              print('خطأ في تحويل Draft Die: $e');
              return null;
            }
          }
          return null;
        });
  }

  // ============================================================
  // ✅ دوال الأفران
  // ============================================================

  @override
  Future<List<FurnaceModel>> getFurnaces(String factoryId) async {
    final List<FurnaceModel> furnaces = [];
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في getFurnaces');
        return furnaces;
      }
      
      print('🔥 جلب الأفران من المصنع: "$cleanFactoryId"');
      
      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('furnaces')
          .once();
      
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        print('📦 عدد الأفران في Firebase: ${data.length}');
        
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final Map<String, dynamic> jsonMap = {};
              (value as Map<dynamic, dynamic>).forEach((k, v) {
                jsonMap[k.toString()] = v;
              });
              
              if (jsonMap['pressId'] == null || jsonMap['pressId'].toString().isEmpty) {
                print('⚠️ فرن بدون pressId: $key - هيظهر برضه لكن غير مربوط بمكبس');
              }
              
              final furnace = FurnaceModel.fromJson(key.toString().trim(), jsonMap);
              furnaces.add(furnace);
              print('✅ تم تحميل الفرن: ${furnace.name} (للمكبس: ${furnace.pressName})');
            } catch (e) {
              print('⚠️ خطأ في تحويل الفرن: $e');
            }
          }
        });
      } else {
        print('⚠️ لا توجد أفران في المصنع');
      }
      
    } catch (e) {
      print('❌ خطأ في جلب الأفران: $e');
    }
    
    print('🔥 تم جلب ${furnaces.length} فرن');
    return furnaces;
  }

  @override
  Future<void> saveFurnace(String factoryId, FurnaceModel furnace) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في saveFurnace');
        return;
      }
      
      print('🔥 حفظ الفرن: ${furnace.name} (للمكبس: ${furnace.pressName})');
      if (furnace.pressId.isEmpty) {
        print('⚠️⚠️ تحذير: جاري حفظ فرن بدون pressId! (${furnace.name})');
      }
      if (furnace.id.isEmpty) {
        throw Exception('لا يمكن حفظ فرن بدون id');
      }
      
      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('furnaces')
          .child(furnace.id)
          .set(furnace.toJson());
      
      print('✅ تم حفظ الفرن: ${furnace.name}');
      
    } catch (e) {
      print('❌ خطأ في حفظ الفرن: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteFurnace(String factoryId, String furnaceId) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في deleteFurnace');
        return;
      }
      
      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('furnaces')
          .child(furnaceId)
          .remove();
      
      print('🗑️ تم حذف الفرن: $furnaceId');
      
    } catch (e) {
      print('❌ خطأ في حذف الفرن: $e');
      rethrow;
    }
  }

  @override
  Future<FurnaceModel?> getFurnace(String factoryId, String furnaceId) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty || furnaceId.isEmpty) {
        return null;
      }
      
      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('furnaces')
          .child(furnaceId)
          .once();
      
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> jsonMap = {};
        (data as Map<dynamic, dynamic>).forEach((k, v) {
          jsonMap[k.toString()] = v;
        });
        return FurnaceModel.fromJson(furnaceId, jsonMap);
      }
      return null;
    } catch (e) {
      print('خطأ في جلب الفرن: $e');
      return null;
    }
  }

  // ============================================================
  // ✅ دوال المكابس
  // ============================================================

  @override
  Future<List<PressModel>> getPresses(String factoryId) async {
    final List<PressModel> presses = [];
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في getPresses');
        return presses;
      }
      
      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('presses')
          .once();
      
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final Map<String, dynamic> jsonMap = {};
              (value as Map<dynamic, dynamic>).forEach((k, v) {
                jsonMap[k.toString()] = v;
              });
              final press = PressModel.fromJson(jsonMap);
              presses.add(press);
              print('✅ تم تحميل المكبس: ${press.name}');
            } catch (e) {
              print('⚠️ خطأ في تحويل المكبس: $e');
            }
          }
        });
      }
      
      if (presses.isEmpty) {
        print('📝 لا توجد مكابس، سيتم إضافة المكابس الافتراضية');
        for (var press in PressModel.getDefaultPresses()) {
          await savePress(factoryId, press);
          presses.add(press);
        }
      }
      
    } catch (e) {
      print('خطأ في جلب المكابس: $e');
    }
    return presses;
  }

  @override
  Future<void> savePress(String factoryId, PressModel press) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في savePress');
        return;
      }
      
      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('presses')
          .child(press.id)
          .set(press.toJson());
      
      print('✅ تم حفظ المكبس: ${press.name}');
      
    } catch (e) {
      print('❌ خطأ في حفظ المكبس: $e');
      rethrow;
    }
  }

  @override
  Future<void> deletePress(String factoryId, String pressId) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في deletePress');
        return;
      }
      
      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('presses')
          .child(pressId)
          .remove();
      
      print('🗑️ تم حذف المكبس: $pressId');
      
    } catch (e) {
      print('❌ خطأ في حذف المكبس: $e');
      rethrow;
    }
  }

  // ============================================================
  // ✅ دوال رصيد الخامة حسب القطر (Material Stock)
  // ============================================================

  @override
  Future<List<MaterialStockModel>> getMaterialStocks(String factoryId) async {
    final List<MaterialStockModel> stocks = [];
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في getMaterialStocks');
        return stocks;
      }
      
      print('📦 جلب رصيد الخامات من المصنع: "$cleanFactoryId"');
      
      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('materialStocks')
          .once();
      
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        print('📦 عدد رصيد الخامات في Firebase: ${data.length}');
        
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final Map<String, dynamic> jsonMap = {};
              (value as Map<dynamic, dynamic>).forEach((k, v) {
                jsonMap[k.toString()] = v;
              });
              final stock = MaterialStockModel.fromJson(key.toString().trim(), jsonMap);
              stocks.add(stock);
              print('✅ تم تحميل رصيد القطر ${stock.diameter} بوصة - سبيكة ${stock.alloy}: ${stock.stock} طن');
            } catch (e) {
              print('⚠️ خطأ في تحويل رصيد الخامة: $e');
            }
          }
        });
      } else {
        print('⚠️ لا يوجد رصيد خامات في المصنع');
      }
      
    } catch (e) {
      print('❌ خطأ في جلب رصيد الخامات: $e');
    }
    
    print('📦 تم جلب ${stocks.length} رصيد خامة');
    return stocks;
  }

  @override
  Future<void> saveMaterialStock(String factoryId, MaterialStockModel stock) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في saveMaterialStock');
        return;
      }
      
      if (stock.id.isEmpty) {
        throw Exception('لا يمكن حفظ رصيد خامة بدون id');
      }
      
      print('📦 حفظ رصيد الخامة: القطر ${stock.diameter} بوصة، السبيكة ${stock.alloy}، الكمية: ${stock.stock} طن');
      
      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('materialStocks')
          .child(stock.id)
          .set(stock.toJson());
      
      print('✅ تم حفظ رصيد القطر ${stock.diameter} بوصة - سبيكة ${stock.alloy}: ${stock.stock} طن');
      
    } catch (e) {
      print('❌ خطأ في حفظ رصيد الخامة: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteMaterialStock(String factoryId, String stockId) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty || stockId.isEmpty) {
        print('⚠️ factoryId أو stockId فارغ في deleteMaterialStock');
        return;
      }
      
      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('materialStocks')
          .child(stockId)
          .remove();
      
      print('🗑️ تم حذف رصيد الخامة: $stockId');
      
    } catch (e) {
      print('❌ خطأ في حذف رصيد الخامة: $e');
      rethrow;
    }
  }

  // ============================================================
  // ✅ دوال الورديات
  // ============================================================

  @override
  Future<String> saveShift(ShiftModel shift) async {
    final factoryId = shift.factoryId.isNotEmpty ? _cleanFactoryId(shift.factoryId.trim()) : await getFactoryId();
    final shiftRef = _database.child('factories').child(factoryId).child('shifts').push();
    await shiftRef.set(shift.toJson());
    await _saveToLocal(shift);
    return shiftRef.key ?? '';
  }

  @override
  Future<void> updateShift(ShiftModel shift) async {
    final factoryId = shift.factoryId.isNotEmpty ? _cleanFactoryId(shift.factoryId.trim()) : await getFactoryId();
    if (shift.id.isEmpty) {
      await saveShift(shift);
      return;
    }
    
    print('📊 حفظ الوردية: ${shift.id}');
    print('📊 عدد القوالب: ${shift.dies.length}');
    for (var die in shift.dies) {
      print('  - ${die.name}: السبيكة ${die.alloy}');
    }
    
    final shiftData = shift.toJson();
    
    await _database
        .child('factories')
        .child(factoryId)
        .child('shifts')
        .child(shift.id)
        .update(shiftData);
    
    await _saveToLocal(shift);
    print('✅ تم حفظ الوردية بنجاح');
  }

  @override
  Future<ShiftModel?> getShiftById(String factoryId, String shiftId) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty || shiftId.isEmpty) {
        return null;
      }
      
      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('shifts')
          .child(shiftId)
          .once();
      
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> jsonMap = {};
        data.forEach((k, v) {
          jsonMap[k.toString()] = v;
        });
        final shift = ShiftModel.fromJson(shiftId, jsonMap);
        print('✅ تم جلب الوردية: ${shift.shiftNumber}، عدد القوالب: ${shift.dies.length}');
        return shift;
      }
      return null;
    } catch (e) {
      print('خطأ في جلب الوردية: $e');
      return null;
    }
  }

  @override
  Stream<List<ShiftModel>> streamAllActiveShifts(String factoryId) {
    final cleanFactoryId = _cleanFactoryId(factoryId.trim());
    return _database
        .child('factories')
        .child(cleanFactoryId)
        .child('shifts')
        .orderByChild('isActive')
        .equalTo(true)
        .onValue
        .map((event) {
          final List<ShiftModel> shifts = [];
          final data = event.snapshot.value;
          if (data != null) {
            try {
              final jsonString = jsonEncode(data);
              final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
              jsonMap.forEach((key, value) {
                if (value is Map<String, dynamic>) {
                  shifts.add(ShiftModel.fromJson(key, value));
                }
              });
            } catch (e) {
              print('خطأ في تحويل البيانات: $e');
            }
          }
          return shifts;
        });
  }

  @override
  Future<List<ShiftModel>> getAllActiveShifts(String factoryId) async {
    final List<ShiftModel> shifts = [];
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في getAllActiveShifts');
        return shifts;
      }
      
      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('shifts')
          .orderByChild('isActive')
          .equalTo(true)
          .once();
      
      if (snapshot.snapshot.value != null) {
        final jsonString = jsonEncode(snapshot.snapshot.value);
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        jsonMap.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            shifts.add(ShiftModel.fromJson(key, value));
          }
        });
      }
    } catch (e) {
      print('خطأ في جلب الورديات النشطة: $e');
    }
    return shifts;
  }

  @override
  Future<List<ShiftModel>> getAllShifts(String factoryId) async {
    final List<ShiftModel> shifts = [];
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) {
        print('⚠️ factoryId فارغ في getAllShifts');
        return shifts;
      }
      
      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('shifts')
          .once();
      
      if (snapshot.snapshot.value != null) {
        final jsonString = jsonEncode(snapshot.snapshot.value);
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        jsonMap.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            shifts.add(ShiftModel.fromJson(key, value));
          }
        });
      }
      
      shifts.sort((a, b) {
        final aEnd = a.endedAt ?? a.createdAt;
        final bEnd = b.endedAt ?? b.createdAt;
        return bEnd.compareTo(aEnd);
      });
      
    } catch (e) {
      print('خطأ في جلب كل الورديات: $e');
    }
    return shifts;
  }

  @override
  Future<void> deleteShift(String factoryId, String id) async {
    await _database.child('factories').child(factoryId.trim()).child('shifts').child(id).remove();
  }

  Future<void> _saveToLocal(ShiftModel shift) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shiftJson = jsonEncode(shift.toJson());
      await prefs.setString('current_shift', shiftJson);
      await prefs.setString('current_shift_id', shift.id);
    } catch (e) {
      print('خطأ في الحفظ المحلي: $e');
    }
  }

  @override
  Future<ShiftModel?> getLocalShift() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shiftJson = prefs.getString('current_shift');
      if (shiftJson != null) {
        final json = jsonDecode(shiftJson) as Map<String, dynamic>;
        final id = prefs.getString('current_shift_id') ?? '';
        return ShiftModel.fromJson(id, json);
      }
    } catch (e) {
      print('خطأ في استرجاع البيانات المحلية: $e');
    }
    return null;
  }

  // ============================================================
  // ✅ دوال القوالب المسجلة (Die Templates)
  // ============================================================

  @override
  Future<List<DieTemplate>> getDieTemplates(String factoryId) async {
    final List<DieTemplate> templates = [];
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) return templates;

      final snapshot = await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('dieTemplates')
          .once();

      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final Map<String, dynamic> jsonMap = {};
              (value as Map<dynamic, dynamic>).forEach((k, v) {
                jsonMap[k.toString()] = v;
              });
              templates.add(DieTemplate.fromJson(key.toString().trim(), jsonMap));
            } catch (e) {
              print('⚠️ خطأ في تحويل القالب: $e');
            }
          }
        });
      }
    } catch (e) {
      print('❌ خطأ في جلب القوالب: $e');
    }
    return templates;
  }

  @override
  Future<void> saveDieTemplate(String factoryId, DieTemplate die) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty) return;

      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('dieTemplates')
          .child(die.id)
          .set(die.toJson());

      print('✅ تم حفظ القالب: ${die.fullCode}');
    } catch (e) {
      print('❌ خطأ في حفظ القالب: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteDieTemplate(String factoryId, String dieId) async {
    try {
      final cleanFactoryId = _cleanFactoryId(factoryId.trim());
      if (cleanFactoryId.isEmpty || dieId.isEmpty) return;

      await _database
          .child('factories')
          .child(cleanFactoryId)
          .child('dieTemplates')
          .child(dieId)
          .remove();

      print('🗑️ تم حذف القالب: $dieId');
    } catch (e) {
      print('❌ خطأ في حذف القالب: $e');
      rethrow;
    }
  }

  @override
  Future<DieTemplate?> getDieTemplateByCode(String factoryId, String code) async {
    try {
      final templates = await getDieTemplates(factoryId);
      final query = code.trim().toLowerCase();

      for (var die in templates) {
        if (die.clientCode.toLowerCase() == query ||
            die.designCode.toLowerCase() == query ||
            die.dieCode.toLowerCase() == query ||
            die.fullCode.toLowerCase() == query) {
          return die;
        }
      }
      return null;
    } catch (e) {
      print('❌ خطأ في البحث عن القالب: $e');
      return null;
    }
  }

  @override
  Future<List<DieTemplate>> searchDieTemplates(String factoryId, String query) async {
    try {
      final templates = await getDieTemplates(factoryId);
      final searchQuery = query.trim().toLowerCase();

      return templates.where((die) {
        return die.name.toLowerCase().contains(searchQuery) ||
            die.clientCode.toLowerCase().contains(searchQuery) ||
            die.designCode.toLowerCase().contains(searchQuery) ||
            die.dieCode.toLowerCase().contains(searchQuery) ||
            die.fullCode.toLowerCase().contains(searchQuery);
      }).toList();
    } catch (e) {
      print('❌ خطأ في البحث عن القوالب: $e');
      return [];
    }
  }

  @override
  Future<List<DieTemplate>> getDieTemplatesByBaseCode(String factoryId, String baseCode) async {
    try {
      final templates = await getDieTemplates(factoryId);
      final query = baseCode.trim().toLowerCase();

      return templates.where((die) {
        return die.dieCode.toLowerCase() == query ||
            die.clientCode.toLowerCase() == query ||
            die.designCode.toLowerCase() == query ||
            die.fullCode.toLowerCase().startsWith(query);
      }).toList();
    } catch (e) {
      print('❌ خطأ في البحث عن النسخ: $e');
      return [];
    }
  }
}

// ============================================================
// 🔥 Provider للوردية والمستخدمين
// ============================================================
class ShiftProvider extends ChangeNotifier {
  final AbstractFirebaseService _service;
  
  ShiftModel? _currentShift;
  bool _isLoading = true;
  List<ShiftModel> _allShifts = [];
  List<ShiftModel> _activeShifts = [];
  String _currentUserUid = '';
  List<UserModel> _users = [];
  UserModel? _currentUser;
  String _currentFactoryId = '';
  List<FactoryModel> _ownerFactories = [];
  List<FactoryModel> _managerFactories = [];
  List<PressModel> _presses = [];
  List<FurnaceModel> _furnaces = [];
  DieModel? _draftDie;
  List<String> _visibleFactoryIds = [];
  List<MaterialStockModel> _materialStocks = [];
  
  bool _isInternalUpdate = false;
  StreamSubscription<DieModel?>? _draftStreamSubscription;

  ShiftModel? get currentShift => _currentShift;
  bool get isLoading => _isLoading;
  AbstractFirebaseService get service => _service;
  List<ShiftModel> get allShifts => _allShifts;
  List<ShiftModel> get activeShifts => _activeShifts;
  String get currentUserUid => _currentUserUid;
  List<UserModel> get users => _users;
  UserModel? get currentUser => _currentUser;
  String get currentFactoryId => _currentFactoryId;
  List<FactoryModel> get ownerFactories => _ownerFactories;
  List<FactoryModel> get managerFactories => _managerFactories;
  List<PressModel> get presses => _presses;
  List<FurnaceModel> get furnaces => _furnaces;
  DieModel? get draftDie => _draftDie;
  List<MaterialStockModel> get materialStocks => _materialStocks;

  ShiftProvider(this._service) {
    _init();
  }

  Future<void> _init() async {
    _currentUserUid = await _service.getCurrentUserUid();
    _currentFactoryId = await _service.getFactoryId();
    await loadAllData();
  }

  Future<void> loadAllData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentFactoryId = await _service.getFactoryId();
      _currentUserUid = await _service.getCurrentUserUid();
      
      print('🔄 تحميل البيانات من المصنع: "$_currentFactoryId"');
      
      _currentUser = await _service.getCurrentUserData();
      
      if (_currentUser != null) {
        if (_currentUser!.isDeveloper) {
          _visibleFactoryIds = [];
          final allFactories = await _service.getAllFactories();
          _ownerFactories = allFactories;
        } else if (_currentUser!.isOwner) {
          _ownerFactories = await _service.getFactoriesForOwner(_currentUserUid);
          _visibleFactoryIds = _ownerFactories.map((f) => f.id).toList();
        } else if (_currentUser!.isManager) {
          _managerFactories = await _service.getFactoriesForManager(_currentUserUid);
          _visibleFactoryIds = _managerFactories.map((f) => f.id).toList();
        } else {
          _visibleFactoryIds = [_currentFactoryId];
        }
      }
      
      if (_currentUser != null && _currentUser!.isDeveloper) {
        final allFactories = await _service.getAllFactories();
        final allFactoryIds = allFactories.map((f) => f.id).toList();
        _users = await _service.getAllUsersForFactories(allFactoryIds);
      } else if (_currentUser != null && _currentUser!.isOwner) {
        final ownerFactoryIds = _currentUser!.factories;
        _users = await _service.getAllUsersForFactories(ownerFactoryIds);
      } else if (_currentUser != null && _currentUser!.isManager) {
        final managerFactoryIds = _currentUser!.managedFactories;
        _users = await _service.getAllUsersForFactories(managerFactoryIds);
      } else {
        _users = await _service.getAllUsers(_currentFactoryId);
      }
      
      print('👥 تم تحميل ${_users.length} مستخدم');
      
      if (_currentUser != null) {
        UserModel? existingUser;
        try {
          existingUser = _users.firstWhere((u) => u.uid == _currentUserUid);
        } catch (e) {
          existingUser = null;
        }
        
        if (existingUser != null) {
          if (existingUser.role != _currentUser!.role ||
              existingUser.assignedPressId != _currentUser!.assignedPressId) {
            final updatedUser = UserModel(
              uid: existingUser.uid,
              email: existingUser.email,
              name: existingUser.name,
              role: _currentUser!.role,
              factoryId: existingUser.factoryId,
              factoryName: existingUser.factoryName,
              factories: existingUser.factories,
              managedFactories: existingUser.managedFactories,
              canEndShift: existingUser.canEndShift,
              assignedPressId: _currentUser!.assignedPressId,
            );
            await _service.updateUser(updatedUser);
            _users = await _service.getAllUsers(_currentFactoryId);
            _currentUser = updatedUser;
          }
        }
      }
      
      _presses = await _service.getPresses(_currentFactoryId);
      print('📏 تم تحميل ${_presses.length} مكبس');
      PressModel.registerPresses(_presses);
      
      _furnaces = await _service.getFurnaces(_currentFactoryId);
      print('🔥 تم تحميل ${_furnaces.length} فرن');
      
      // ✅ تحميل رصيد الخامات
      _materialStocks = await _service.getMaterialStocks(_currentFactoryId);
      print('📦 تم تحميل ${_materialStocks.length} رصيد خامة');
      
      _allShifts = await _service.getAllShifts(_currentFactoryId);
      _activeShifts = await _service.getAllActiveShifts(_currentFactoryId);
      
      if (_activeShifts.isNotEmpty) {
        _currentShift = _activeShifts.first;
        await _loadDraftDie();
        _listenToDraftDie();
      } else {
        _currentShift = null;
        _draftDie = null;
        _draftStreamSubscription?.cancel();
      }
      
      _service.streamAllActiveShifts(_currentFactoryId).listen((shifts) {
        if (_isInternalUpdate) {
          _isInternalUpdate = false;
          return;
        }
        
        _activeShifts = shifts;
        
        if (_currentShift != null) {
          final currentShiftId = _currentShift!.id;
          ShiftModel? updatedCurrentShift;
          try {
            updatedCurrentShift = _activeShifts.firstWhere((s) => s.id == currentShiftId);
          } catch (e) {
            updatedCurrentShift = null;
          }
          
          if (updatedCurrentShift != null) {
            _currentShift = updatedCurrentShift;
            _loadDraftDie();
          } else {
            if (_activeShifts.isNotEmpty) {
              _currentShift = _activeShifts.first;
              _loadDraftDie();
            } else {
              _currentShift = null;
              _draftDie = null;
              _draftStreamSubscription?.cancel();
            }
          }
        } else {
          if (_activeShifts.isNotEmpty) {
            _currentShift = _activeShifts.first;
            _loadDraftDie();
          }
        }
        
        notifyListeners();
      });
      
    } catch (e) {
      print('❌ خطأ في تحميل البيانات: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadDraftDie() async {
    if (_currentShift == null) {
      _draftDie = null;
      _draftStreamSubscription?.cancel();
      return;
    }
    
    try {
      final draft = await _service.getDraftDie(_currentFactoryId, _currentShift!.id);
      _draftDie = draft;
      if (draft != null) {
        print('✅ تم تحميل القالب قيد الإدخال: ${draft.name}');
      }
      _listenToDraftDie();
    } catch (e) {
      print('خطأ في تحميل القالب قيد الإدخال: $e');
      _draftDie = null;
    }
  }

  void _listenToDraftDie() {
    _draftStreamSubscription?.cancel();
    if (_currentShift == null) return;
    
    _draftStreamSubscription = _service.streamDraftDie(_currentFactoryId, _currentShift!.id).listen((draft) {
      _draftDie = draft;
      notifyListeners();
      if (draft != null) {
        print('🔄 تم تحديث القالب قيد الإدخال من Firebase: ${draft.name}');
      } else {
        print('🗑️ تم حذف القالب قيد الإدخال');
      }
    });
  }

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  Future<void> saveDraftDie(DieModel draftDie) async {
    if (_currentShift == null) {
      print('⚠️ لا توجد وردية نشطة');
      return;
    }
    
    try {
      _isInternalUpdate = true;
      await _service.saveDraftDie(_currentFactoryId, _currentShift!.id, draftDie);
    } catch (e) {
      print('❌ خطأ في حفظ القالب قيد الإدخال: $e');
      rethrow;
    } finally {
      _isInternalUpdate = false;
    }
  }

  Future<void> saveDraftDieLocal(DieModel draftDie) async {
    _draftDie = draftDie;
    notifyListeners();
    print('✅ تم حفظ القالب قيد الإدخال محلياً: ${draftDie.name}');
  }

  Future<void> deleteDraftDie() async {
    if (_currentShift == null) {
      print('⚠️ لا توجد وردية نشطة');
      return;
    }
    
    try {
      _isInternalUpdate = true;
      await _service.deleteDraftDie(_currentFactoryId, _currentShift!.id);
    } catch (e) {
      print('❌ خطأ في حذف القالب قيد الإدخال: $e');
      rethrow;
    } finally {
      _isInternalUpdate = false;
    }
  }

  Future<void> addDieDirect(DieModel die) async {
    if (_currentShift == null) {
      Fluttertoast.showToast(
        msg: '⚠️ لا توجد وردية نشطة',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (!canAddDie) {
      Fluttertoast.showToast(
        msg: '⚠️ ليس لديك صلاحية لإضافة قالب',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final newDie = die.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        supervisorId: _currentUserUid,
        status: DieStatus.active,
      );

      final updatedShift = _currentShift!.addDie(newDie);
      
      _isInternalUpdate = true;
      await _service.updateShift(updatedShift);

      _currentShift = updatedShift;

      await _service.deleteDraftDie(_currentFactoryId, _currentShift!.id);
      _draftDie = null;

      final newActiveShifts = <ShiftModel>[];
      for (var shift in _activeShifts) {
        if (shift.id == _currentShift!.id) {
          newActiveShifts.add(_currentShift!);
        } else {
          newActiveShifts.add(shift);
        }
      }
      _activeShifts = newActiveShifts;

      final newAllShifts = <ShiftModel>[];
      for (var shift in _allShifts) {
        if (shift.id == _currentShift!.id) {
          newAllShifts.add(_currentShift!);
        } else {
          newAllShifts.add(shift);
        }
      }
      _allShifts = newAllShifts;

      notifyListeners();

      Fluttertoast.showToast(
        msg: '✅ تم إضافة القالب ${newDie.name} بنجاح (${updatedShift.dies.length} قالب)',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

    } catch (e) {
      print('❌ خطأ في إضافة القالب: $e');
      Fluttertoast.showToast(
        msg: '❌ خطأ في إضافة القالب: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      rethrow;
    } finally {
      _isInternalUpdate = false;
    }
  }

  Future<void> addWastedTime(int minutes, String reason) async {
    if (_currentShift == null || !_currentShift!.isActive) {
      Fluttertoast.showToast(
        msg: '⚠️ لا توجد وردية نشطة',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final updatedShift = _currentShift!.addWastedTime(minutes, reason);
      
      _isInternalUpdate = true;
      await _service.updateShift(updatedShift);

      _currentShift = updatedShift;

      final newActiveShifts = <ShiftModel>[];
      for (var shift in _activeShifts) {
        if (shift.id == _currentShift!.id) {
          newActiveShifts.add(_currentShift!);
        } else {
          newActiveShifts.add(shift);
        }
      }
      _activeShifts = newActiveShifts;

      final newAllShifts = <ShiftModel>[];
      for (var shift in _allShifts) {
        if (shift.id == _currentShift!.id) {
          newAllShifts.add(_currentShift!);
        } else {
          newAllShifts.add(shift);
        }
      }
      _allShifts = newAllShifts;

      notifyListeners();

      Fluttertoast.showToast(
        msg: '✅ تم تسجيل وقت العطل: $minutes دقيقة (${reason.length > 25 ? reason.substring(0, 25) + '...' : reason})',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

    } catch (e) {
      print('خطأ في تسجيل وقت العطل: $e');
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      rethrow;
    } finally {
      _isInternalUpdate = false;
    }
  }

  // ✅ دوال إنتاج الشهر
  double getMonthlyProductionForPress(String pressId) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);
    
    double totalWeight = 0.0;
    
    for (var shift in _allShifts) {
      if (shift.isActive) continue;
      if (shift.pressId != pressId) continue;
      if (shift.createdAt.isAfter(startOfMonth) && shift.createdAt.isBefore(endOfMonth)) {
        totalWeight += shift.totalWeight;
      }
    }
    
    return totalWeight;
  }

  double get currentPressMonthlyProduction {
    if (_currentShift == null) return 0.0;
    return getMonthlyProductionForPress(_currentShift!.pressId);
  }

  String getCurrentPressMonthlyProductionFormatted() {
    final weight = currentPressMonthlyProduction;
    if (weight >= 1000) {
      return '${(weight / 1000).toStringAsFixed(2)} طن';
    }
    return '${weight.toStringAsFixed(2)} كجم';
  }

  String getMonthlyProductionFormattedForPress(String pressId) {
    final weight = getMonthlyProductionForPress(pressId);
    if (weight >= 1000) {
      return '${(weight / 1000).toStringAsFixed(2)} طن';
    }
    return '${weight.toStringAsFixed(2)} كجم';
  }

  // ✅ دوال Target Waste %
  double getTargetWastePercentageForPress(String pressId) {
    final press = getPressById(pressId);
    if (press == null) return 20.0;
    return press.targetWastePercentage;
  }

  // ✅ دوال الأفران
  FurnaceModel? getFurnaceById(String id) {
    try {
      return _furnaces.firstWhere((f) => f.id == id);
    } catch (e) {
      return null;
    }
  }

  FurnaceModel? getFurnaceByPressId(String pressId) {
    try {
      return _furnaces.firstWhere((f) => f.pressId == pressId);
    } catch (e) {
      return null;
    }
  }

  List<FurnaceModel> getActiveFurnaces() {
    return _furnaces.where((f) => f.isActive).toList();
  }

  List<PressModel> getActivePresses() {
    final activePressIds = _activeShifts.map((s) => s.pressId).toList();
    return _presses.where((p) => activePressIds.contains(p.id)).toList();
  }

  List<PressModel> getInactivePresses() {
    final activePressIds = _activeShifts.map((s) => s.pressId).toList();
    final inactive = _presses.where((p) => !activePressIds.contains(p.id)).toList();
    return inactive;
  }

  ShiftModel? getShiftForPress(String pressId) {
    try {
      return _activeShifts.firstWhere((shift) => shift.pressId == pressId);
    } catch (e) {
      return null;
    }
  }

  bool hasActiveShiftForPress(String pressId) {
    return _activeShifts.any((shift) => shift.pressId == pressId);
  }

  bool canStartShiftForPress(String pressId) {
    final user = _currentUser;
    if (user == null) return false;
    return user.canStartShiftForPress(pressId);
  }

  PressModel? getPressById(String id) {
    try {
      return _presses.firstWhere((press) => press.id == id);
    } catch (e) {
      return PressModel.getPressById(id);
    }
  }

  Future<void> startNewShift({
    required String supervisor,
    required String technician,
    required String pressId,
    required int shiftNumber,
    String? pressSupervisorUid,
  }) async {
    try {
      final press = getPressById(pressId);
      if (press == null) {
        Fluttertoast.showToast(
          msg: '⚠️ المكبس غير موجود. يرجى تحديث القائمة.',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      if (hasActiveShiftForPress(pressId)) {
        Fluttertoast.showToast(
          msg: '⚠️ هناك وردية نشطة بالفعل للمكبس ${press.name}',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      _currentFactoryId = await _service.getFactoryId();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      _currentUserUid = await _service.getCurrentUserUid();

      final newShift = ShiftModel(
        factoryId: _currentFactoryId,
        date: today,
        shiftNumber: shiftNumber,
        supervisor: supervisor,
        technician: technician,
        pressId: pressId,
        pressName: press.name,
        pressSize: press.size,
        supervisorUid: _currentUserUid,
        pressSupervisorUid: pressSupervisorUid ?? _currentUserUid,
        dies: [],
        isActive: true,
        createdAt: DateTime.now(),
      );

      _isInternalUpdate = true;
      await _service.saveShift(newShift);
      await loadAllData();
      
      Fluttertoast.showToast(
        msg: '✅ تم بدء وردية جديدة للمكبس ${press.name}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      
    } catch (e) {
      print('خطأ في بدء الوردية: $e');
      rethrow;
    } finally {
      _isInternalUpdate = false;
    }
  }

  Future<void> updateDie(DieModel updatedDie) async {
    if (_currentShift == null) return;
    if (!canAddDie) {
      Fluttertoast.showToast(
        msg: '⚠️ ليس لديك صلاحية لتحديث هذا القالب',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }
    try {
      final updatedShift = _currentShift!.updateDie(updatedDie);
      
      _isInternalUpdate = true;
      await _service.updateShift(updatedShift);
      
      _currentShift = updatedShift;
      
      final newActiveShifts = <ShiftModel>[];
      for (var shift in _activeShifts) {
        if (shift.id == _currentShift!.id) {
          newActiveShifts.add(_currentShift!);
        } else {
          newActiveShifts.add(shift);
        }
      }
      _activeShifts = newActiveShifts;
      
      final newAllShifts = <ShiftModel>[];
      for (var shift in _allShifts) {
        if (shift.id == _currentShift!.id) {
          newAllShifts.add(_currentShift!);
        } else {
          newAllShifts.add(shift);
        }
      }
      _allShifts = newAllShifts;
      
      notifyListeners();
      
      Fluttertoast.showToast(
        msg: '🔄 تم تحديث القالب: ${updatedDie.name}',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      
    } catch (e) {
      print('خطأ في تحديث القالب: $e');
      rethrow;
    } finally {
      _isInternalUpdate = false;
    }
  }

  Future<void> updateDieInShift(String shiftId, DieModel updatedDie) async {
    if (shiftId.isEmpty) {
      print('⚠️ shiftId فارغ في updateDieInShift');
      return;
    }

    try {
      ShiftModel? targetShift;
      try {
        targetShift = _allShifts.firstWhere((s) => s.id == shiftId);
      } catch (e) {
        targetShift = null;
      }

      targetShift ??= await _service.getShiftById(_currentFactoryId, shiftId);

      if (targetShift == null) {
        print('⚠️ لم يتم العثور على الوردية $shiftId لتحديث القالب');
        return;
      }

      final updatedShift = targetShift.updateDie(updatedDie);

      _isInternalUpdate = true;
      await _service.updateShift(updatedShift);

      if (_currentShift != null && _currentShift!.id == shiftId) {
        _currentShift = updatedShift;
      }

      _activeShifts = _activeShifts
          .map((s) => s.id == shiftId ? updatedShift : s)
          .toList();

      _allShifts = _allShifts
          .map((s) => s.id == shiftId ? updatedShift : s)
          .toList();

      notifyListeners();

      Fluttertoast.showToast(
        msg: '🔄 تم تحديث القالب: ${updatedDie.name}',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    } catch (e) {
      print('❌ خطأ في تحديث القالب داخل الوردية $shiftId: $e');
      rethrow;
    } finally {
      _isInternalUpdate = false;
    }
  }

  bool canManagePress(String pressId) {
    final user = _currentUser;
    if (user == null) return false;
    if (user.isDeveloper) return true;
    if (user.isOwner) return true;
    if (user.isManager) return true;
    if (user.isSupervisor) {
      return user.assignedPressId == pressId;
    }
    return false;
  }

  bool canManageFurnace(String furnaceId) {
    final furnace = getFurnaceById(furnaceId);
    if (furnace == null) return false;
    return canManagePress(furnace.pressId);
  }

  // ============================================================
  // ✅ دوال إدارة رصيد الخامة حسب القطر
  // ============================================================

  // ✅ الحصول على رصيد قطر معين وسبيكة معينة
  double getMaterialStockForDiameterAndAlloy(double diameter, String alloy) {
    final stocks = _materialStocks.where((s) =>
        s.diameter == diameter && s.alloy == alloy
    ).toList();
    if (stocks.isNotEmpty) {
      return stocks.fold(0.0, (sum, s) => sum + s.stock);
    }
    return 0.0;
  }

  // ✅ الحصول على رصيد قطر معين (جميع السبائك)
  double getMaterialStockForDiameter(double diameter) {
    return _materialStocks
        .where((s) => s.diameter == diameter)
        .fold(0.0, (sum, s) => sum + s.stock);
  }

  // ✅ إضافة رصيد لقطر معين وسبيكة معينة
  Future<void> addMaterialToDiameterAndAlloy(double diameter, String alloy, String origin, double amount, {String? notes}) async {
    if (!canManageMaterialStock) {
      Fluttertoast.showToast(
        msg: '⚠️ ليس لديك صلاحية لإضافة رصيد',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }
    
    // ✅ التحقق من وجود رصيد بنفس القطر والسبيكة والمنشأ
    final existing = _materialStocks.where((s) =>
        s.diameter == diameter &&
        s.alloy == alloy &&
        s.origin == origin
    ).toList();

    MaterialStockModel stock;
    if (existing.isNotEmpty) {
      stock = existing.first.addStock(amount);
    } else {
      final diameterStr = diameter.toStringAsFixed(1).replaceAll('.', '_');
      stock = MaterialStockModel(
        id: 'stock_${diameterStr}_${alloy}_${origin}_${DateTime.now().millisecondsSinceEpoch}',
        diameter: diameter,
        stock: amount,
        factoryId: _currentFactoryId,
        alloy: alloy,
        origin: origin,
        notes: notes,
      );
    }

    await _service.saveMaterialStock(_currentFactoryId, stock);
    
    // تحديث القائمة المحلية
    final index = _materialStocks.indexWhere((s) => s.id == stock.id);
    if (index != -1) {
      _materialStocks[index] = stock;
    } else {
      _materialStocks.add(stock);
    }
    
    notifyListeners();
    
    Fluttertoast.showToast(
      msg: '✅ تم إضافة ${amount.toStringAsFixed(2)} طن من سبيكة $alloy للقطر ${diameter.toStringAsFixed(1)} بوصة',
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  // ✅ خصم رصيد حسب الاستهلاك الفعلي للوردية (لكل سبيكة على حدة)
  Future<void> deductMaterialForShift(ShiftModel shift) async {
    print('🔥 deductMaterialForShift بدأت للوردية: ${shift.id}');
    
    final press = getPressById(shift.pressId);
    if (press == null) {
      print('⚠️ لا يمكن العثور على المكبس: ${shift.pressId}');
      return;
    }
    
    final diameter = press.diameterInInches;
    
    // ✅ حساب الاستهلاك لكل سبيكة
    final consumptionByAlloy = shift.getConsumedWeightByAlloy();
    
    if (consumptionByAlloy.isEmpty) {
      print('⚠️ لا يوجد استهلاك في الوردية');
      return;
    }
    
    print('📦 القطر: $diameter بوصة');
    print('📦 الاستهلاك حسب السبيكة: $consumptionByAlloy');
    
    // ✅ الخصم لكل سبيكة على حدة
    for (var entry in consumptionByAlloy.entries) {
      final alloy = entry.key;
      final consumedWeight = entry.value;
      
      if (consumedWeight <= 0) continue;
      
      print('📦 خصم $consumedWeight طن من سبيكة $alloy للقطر $diameter بوصة');
      
      // ✅ الأولوية: مستوردة → محلي → محلي مسبك
      double remaining = consumedWeight;
      final priorityOrder = ['imported', 'local', 'local_foundry'];
      
      for (var origin in priorityOrder) {
        if (remaining <= 0) break;
        
        final stocks = _materialStocks.where((s) =>
            s.diameter == diameter &&
            s.alloy == alloy &&
            s.origin == origin
        ).toList();
        
        if (stocks.isEmpty) continue;
        
        final currentStock = stocks.first;
        final double deductAmount = remaining.clamp(0, currentStock.stock).toDouble(); // ✅ التعديل هنا
        
        if (deductAmount > 0) {
          final updatedStock = currentStock.consumeStock(deductAmount);
          await _service.saveMaterialStock(_currentFactoryId, updatedStock);
          
          // تحديث القائمة المحلية
          final index = _materialStocks.indexWhere((s) => s.id == updatedStock.id);
          if (index != -1) {
            _materialStocks[index] = updatedStock;
          }
          
          remaining -= deductAmount;
          print('✅ تم خصم $deductAmount طن من $origin، المتبقي: $remaining');
        }
      }
      
      if (remaining > 0) {
        print('⚠️ رصيد غير كافٍ لسبيكة $alloy، المتبقي غير مخصوم: $remaining طن');
        Fluttertoast.showToast(
          msg: '⚠️ رصيد غير كافٍ للقطر $diameter بوصة والسبيكة $alloy (المتبقي غير مخصوم: ${remaining.toStringAsFixed(2)} طن)',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
    
    notifyListeners();
    print('✅ تم الانتهاء من خصم رصيد الوردية');
  }

  // ✅ صلاحية إدارة الرصيد
  bool get canManageMaterialStock {
    if (_currentUser == null) return false;
    return _currentUser!.canManageMaterialStock;
  }

  // ✅ صلاحية تعديل بيانات الإنتاج
  bool get canEditProductionData {
    if (_currentUser == null) return false;
    return _currentUser!.canEditProductionData;
  }

  // ✅ صلاحية إضافة رصيد
  bool get canAddMaterialStock {
    if (_currentUser == null) return false;
    return _currentUser!.canAddMaterialStock;
  }

  // ============================================================
  // ✅ نهاية دوال إدارة رصيد الخامة
  // ============================================================

  Future<void> endShift() async {
    if (_currentShift == null) {
      Fluttertoast.showToast(
        msg: '⚠️ لا توجد وردية نشطة',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }
    
    if (!canEndCurrentShift) {
      Fluttertoast.showToast(
        msg: '⚠️ ليس لديك صلاحية لإنهاء هذه الوردية',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }
    
    try {
      final endedShift = _currentShift!.endShift();
      
      _isInternalUpdate = true;
      await _service.updateShift(endedShift);
      
      // ✅ خصم رصيد الخامة حسب الاستهلاك الفعلي لكل سبيكة
      await deductMaterialForShift(endedShift);
      
      final press = getPressById(endedShift.pressId);
      final pressName = press?.name ?? endedShift.pressName;
      final diameter = press?.diameterInInches ?? 0;
      
      // ✅ عرض ملخص الاستهلاك حسب السبيكة
      final consumption = endedShift.getConsumedWeightByAlloy();
      String summary = '';
      for (var entry in consumption.entries) {
        summary += '\n- ${entry.key}: ${entry.value.toStringAsFixed(2)} طن';
      }
      
      _currentShift = null;
      _draftDie = null;
      _draftStreamSubscription?.cancel();
      
      await loadAllData();
      
      Fluttertoast.showToast(
        msg: '✅ تم إنهاء الوردية.\n'
             '📦 إجمالي الوزن: ${endedShift.totalWeightFormatted}\n'
             '📊 الاستهلاك حسب السبيكة:$summary',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
      
    } catch (e) {
      print('خطأ في إنهاء الوردية: $e');
      Fluttertoast.showToast(
        msg: '❌ خطأ في إنهاء الوردية: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      rethrow;
    } finally {
      _isInternalUpdate = false;
    }
  }

  Future<void> loadShift(String shiftId) async {
    try {
      _currentFactoryId = await _service.getFactoryId();
      
      _allShifts = await _service.getAllShifts(_currentFactoryId);
      _activeShifts = await _service.getAllActiveShifts(_currentFactoryId);
      
      ShiftModel? shift;
      try {
        shift = _allShifts.firstWhere((s) => s.id == shiftId);
      } catch (e) {
        shift = null;
      }
      
      if (shift == null) {
        Fluttertoast.showToast(
          msg: '❌ الوردية غير موجودة',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
      
      _currentShift = shift;
      await _loadDraftDie();
      
      notifyListeners();
      
      Fluttertoast.showToast(
        msg: '📋 تم تحميل الوردية #${shift.shiftNumber} - ${shift.pressName} (${shift.dies.length} قالب)',
        backgroundColor: Colors.blue,
        textColor: Colors.white,
      );
    } catch (e) {
      print('خطأ في تحميل الوردية: $e');
      Fluttertoast.showToast(
        msg: '❌ خطأ في تحميل الوردية: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  bool canEndShift(String shiftId) {
    ShiftModel? shift;
    try {
      shift = _allShifts.firstWhere((s) => s.id == shiftId);
    } catch (e) {
      shift = null;
    }
    if (shift == null) return false;
    final user = _currentUser;
    if (user == null) return false;
    if (user.isDeveloper) return true;
    if (user.isOwner) return user.canEndShift;
    if (user.isManager) return user.canEndShift;
    if (shift.supervisorUid == _currentUserUid) return true;
    if (shift.pressSupervisorUid == _currentUserUid) return true;
    return user.canEndShift;
  }

  bool get canEndCurrentShift {
    if (_currentShift == null) return false;
    return canEndShift(_currentShift!.id);
  }

  bool get canAddDie {
    if (_currentShift == null) return false;
    if (_currentUser?.isDeveloper ?? false) return true;
    if (_currentUser?.isOwner ?? false) return true;
    if (_currentUser?.isManager ?? false) return true;
    if (_currentShift!.supervisorUid == _currentUserUid) return true;
    if (_currentShift!.pressSupervisorUid == _currentUserUid) return true;
    return false;
  }

  bool get isDeveloper => _currentUser?.isDeveloper ?? false;
  bool get isOwner => _currentUser?.isOwner ?? false;
  bool get isManager => _currentUser?.isManager ?? false;
  bool get isSupervisor => _currentUser?.isSupervisor ?? false;
  bool get isOperator => _currentUser?.isOperator ?? false;
  bool get isProductionMonitor => _currentUser?.isProductionMonitor ?? false;

  Future<void> switchFactory(String factoryId) async {
    try {
      await _service.setFactoryId(factoryId);
      _currentFactoryId = factoryId;
      await loadAllData();
      Fluttertoast.showToast(
        msg: '✅ تم التبديل إلى المصنع: $factoryId',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'خطأ في التبديل: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> updateUserFactory(String uid, String newFactoryId, String newFactoryName) async {
    try {
      await _service.updateUserFactory(uid, newFactoryId, newFactoryName);
      await loadAllData();
      Fluttertoast.showToast(
        msg: '✅ تم تحديث مصنع المستخدم',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ خطأ في تحديث المصنع: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      rethrow;
    }
  }

  Future<void> addUser(UserModel user) async {
    try {
      await _service.saveUser(user);
      await loadAllData();
      if (user.uid == _currentUserUid) {
        _currentUser = user;
      }
      Fluttertoast.showToast(
        msg: '✅ تم إضافة المستخدم ${user.name}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      print('خطأ في إضافة المستخدم: $e');
      rethrow;
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _service.updateUser(user);
      await loadAllData();
      if (user.uid == _currentUserUid) {
        _currentUser = user;
        await _service.refreshUserPermissions();
      }
      Fluttertoast.showToast(
        msg: '✅ تم تحديث المستخدم ${user.name}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      print('خطأ في تحديث المستخدم: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      await _service.deleteUser(uid);
      await loadAllData();
      Fluttertoast.showToast(
        msg: '✅ تم حذف المستخدم',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('خطأ في حذف المستخدم: $e');
      rethrow;
    }
  }

  Future<void> refreshCurrentUserPermissions() async {
    await _service.refreshUserPermissions();
    _currentUser = await _service.getCurrentUserData();
    await loadAllData();
    notifyListeners();
  }

  Future<void> switchToFactory(String factoryId) async {
    if (!isOwner && !isDeveloper && !isManager) {
      Fluttertoast.showToast(
        msg: '⚠️ ليس لديك صلاحية للتبديل بين المصانع',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }
    await switchFactory(factoryId);
  }

  double get totalWeight {
    if (_currentShift == null) return 0.0;
    return _currentShift!.totalWeight;
  }

  String get totalWeightFormatted {
    if (_currentShift == null) return '0.00 كجم';
    return _currentShift!.totalWeightFormatted;
  }

  int get activePressCount {
    if (_currentShift == null) return 0;
    return _currentShift!.activePressCount;
  }

  int get totalActivePressesInFactory {
    return _activeShifts.fold(0, (sum, shift) => sum + shift.activePressCount);
  }

  double get currentShiftEfficiency {
    if (_currentShift == null) return 0.0;
    final press = getPressById(_currentShift!.pressId);
    if (press == null) return 0.0;
    return _currentShift!.getEfficiency(press.targetTonsPerHour);
  }

  String get currentShiftEfficiencyFormatted {
    final efficiency = currentShiftEfficiency;
    return '${efficiency.toStringAsFixed(1)}%';
  }

  Color getEfficiencyColor(double efficiency) {
    if (efficiency >= 90) return Colors.green;
    if (efficiency >= 75) return Colors.orange;
    if (efficiency >= 50) return Colors.orange.shade700;
    return Colors.red;
  }

  String getEfficiencyEmoji(double efficiency) {
    if (efficiency >= 90) return '🌟';
    if (efficiency >= 75) return '✅';
    if (efficiency >= 50) return '⚠️';
    return '❌';
  }
}