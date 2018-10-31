#!/usr/bin/env python3
#
# Intel AMT wsman driver
# Inspired by OpenStack's Ironic AMT driver from ironic-staging-drivers.
#
# Copyright (C) 2018  Juerg Haefliger <juergh@gmail.com>
# Copyright (C) 2018  OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

from xml.etree import ElementTree


def xml_find(doc, namespace, item):
    """
    Find the first element with namespace and item, in the XML doc
    """
    if doc is None:
        raise Exception("xml_find (doc = None)")

    tree = ElementTree.fromstring(doc.root().string())
    query = (".//{%s}%s" % (namespace, item))
    return tree.find(query)
