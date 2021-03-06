// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_test_handler/shelf_test_handler.dart';
import 'package:test/test.dart';

import '../descriptor.dart' as d;
import '../test_pub.dart';
import 'utils.dart';

main() {
  // Regression test for issue 8849.
  test(
      'with a server-rejected refresh token, authenticates again and '
      'saves credentials.json', () async {
    await d.validPackage.create();

    var server = await ShelfTestServer.create();
    await d
        .credentialsFile(server, 'access token',
            refreshToken: 'bad refresh token',
            expiration: DateTime.now().subtract(Duration(hours: 1)))
        .create();

    var pub = await startPublish(server);

    await confirmPublish(pub);

    server.handler.expect('POST', '/token', (request) {
      return request.read().drain().then((_) {
        return shelf.Response(400,
            body: jsonEncode({"error": "invalid_request"}),
            headers: {'content-type': 'application/json'});
      });
    });

    await expectLater(pub.stdout, emits(startsWith('Uploading...')));
    await authorizePub(pub, server, 'new access token');

    server.handler.expect('GET', '/api/packages/versions/new', (request) {
      expect(request.headers,
          containsPair('authorization', 'Bearer new access token'));

      return shelf.Response(200);
    });

    await pub.kill();
  });
}
