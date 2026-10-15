import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/constants/api_constants.dart';
import 'package:zuno/features/auth/domain/entities/user.dart';
import 'package:zuno/features/customer/presentation/screens/customer_home_header.dart';
import 'package:zuno/shared/widgets/profile_avatar.dart';

/// The account picture, in the header and on the profile page.
///
/// The header showed the first letter of the customer's name and nothing else, so somebody who had
/// just set a profile picture opened the home page and found it missing. Both places read the
/// picture through [ProfileAvatar] now, and these tests are what stops the header regressing to a
/// letter again.
User _user({String? photo}) => User(
  id: 'u1',
  email: 'cust@zuno.local',
  phoneNumber: '9100007530',
  firstName: 'Cust',
  lastName: 'T',
  profileImageUrl: photo,
  role: 'Customer',
  emailConfirmed: false,
  phoneNumberConfirmed: false,
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('the address of the picture', () {
    test('is the API host plus the stored path', () {
      expect(
        ProfileAvatar.photoUrlFor(_user(photo: '/uploads/users/u1/photo.jpg')),
        '${ApiConstants.baseUrl}/uploads/users/u1/photo.jpg',
      );
    });

    test('is nothing when no picture is set', () {
      expect(ProfileAvatar.photoUrlFor(_user()), isNull);
      // An empty string is what a cleared picture can arrive as, and it must not be treated as a
      // path — it would resolve to the API root and fetch the wrong thing.
      expect(ProfileAvatar.photoUrlFor(_user(photo: '')), isNull);
      expect(ProfileAvatar.photoUrlFor(null), isNull);
    });
  });

  group('ProfileAvatar', () {
    testWidgets('fetches the picture when one is set', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileAvatar(user: _user(photo: '/uploads/users/u1/photo.jpg')),
        ),
      );

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        image.imageUrl,
        '${ApiConstants.baseUrl}/uploads/users/u1/photo.jpg',
      );
    });

    testWidgets('falls back to the first letter of the name', (tester) async {
      await tester.pumpWidget(_wrap(ProfileAvatar(user: _user())));

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('shows a letter even with no one signed in', (tester) async {
      await tester.pumpWidget(_wrap(const ProfileAvatar(user: null)));

      expect(find.text('?'), findsOneWidget);
    });
  });

  group('the customer home header', () {
    testWidgets('shows the signed-in picture, not just a letter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CustomerHomeHeader(
            user: _user(photo: '/uploads/users/u1/photo.jpg'),
            location: 'Thiruvananthapuram',
          ),
        ),
      );

      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(find.text('Cust T'), findsOneWidget);
    });

    testWidgets('still renders for a customer with no picture', (tester) async {
      await tester.pumpWidget(_wrap(CustomerHomeHeader(user: _user())));

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('Everywhere'), findsOneWidget);
    });
  });
}
