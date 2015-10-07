/**
 * Copyright 2013-2015, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 * @providesModule generateRQLFieldAlias
 * @typechecks
 */

'use strict';

var crc32 = require('fbjs/lib/crc32');

var PREFIX = '_';

/**
 * Sanitizes a stringified GraphQL field (including any calls and their values)
 * to produce a valid alias.
 *
 * This is used to auto-alias fields in generated queries, so that developers
 * composing multiple components together don't have to worry about collisions
 * between components requesting the same fields. (Explicit aliases are only
 * needed within a single component when it uses the same field multiple times,
 * in order to differentiate these fields in the props).
 *
 * @internal
 *
 * @param {string} input
 * @return {string}
 */
function generateRQLFieldAlias(input) {
  // Field names with no calls can be used as aliases without encoding
  var index = input.indexOf('.');
  if (index === -1) {
    return input;
  }

  return PREFIX + input.substr(0, index) + Math.abs(crc32(input)).toString(36);
}

module.exports = generateRQLFieldAlias;