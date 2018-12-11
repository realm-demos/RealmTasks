// //////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// //////////////////////////////////////////////////////////////////////////

'use strict';

import {
    Navigator,
    Platform,
    StyleSheet,
} from 'react-native';

const { NavBarHeight, TotalNavHeight } = Navigator.NavigationBar.Styles.General;
const iOS = (Platform.OS === 'ios');

const colors = {
  charcoal: '#1c233f',
  peach: '#fc9f95',
  melon: '#fcc397',
  elephant: '#9a9ba5',
  sexysalmon: '#f77c88',
  flamingo: '#f25192',
  mulberry: '#d34ca3',
  grape_jelly: '#9a50a5',
  indigo: '#59569e',
  ultramarine: '#39477f',
};

const styles = {
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'stretch',
    backgroundColor: colors.charcoal,
  },
  navigator: {
    flex: 1,
  },
  navBar: {
    backgroundColor: '#E7A776',
  },
  navBarView: {
    alignItems: 'center',
    flexDirection: 'row',
    height: NavBarHeight,
  },
  navBarLeftArrow: {
    color: 'white',
    fontSize: 40,
    fontWeight: '200',
    letterSpacing: 2,
    marginTop: -6,
  },
  navBarLeftButton: {
    paddingLeft: 8,
  },
  navBarRightButton: {
    paddingRight: 8,
  },
  navBarText: {
    color: 'white',
    fontSize: 18,
  },
  navBarTitleText: {
    fontWeight: '500',
  },
  navScene: {
    top: TotalNavHeight,
  },

  listItem: {
    borderBottomWidth: 0,
    alignItems: 'stretch',
    alignSelf: 'stretch',
    justifyContent: 'center',
    flexDirection: 'row',
    flex: 1,
    height: 44,
  },
  listItemLeftSide: {
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    width: 36,
  },
  listItemCheckbox: {
    borderColor: '#ccc',
    borderWidth: 1,
    width: 16,
    height: 16,
  },
  listItemCheckboxText: {
    width: 14,
    height: 14,
    fontSize: iOS ? 14 : 10,
    textAlign: 'center',
  },
  listItemCount: {
    borderColor: '#ccc',
    borderWidth: 1,
    borderRadius: 8,
    width: 24,
    height: 18,
  },
  listItemCountText: {
    backgroundColor: 'transparent',
    fontSize: iOS ? 12 : 11,
    textAlign: 'center',
  },
  listItemInput: {
    fontFamily: 'System',
    fontSize: 15,
    flexDirection: 'column',
    flex: 1,
  },
  listItemText: {
    alignSelf: 'center',
    fontFamily: 'System',
    fontSize: 15,
    flexDirection: 'column',
    flex: 1,
  },
  listItemTextSpecial: {
    fontStyle: 'italic',
  },
  listItemDelete: {
    backgroundColor: 'transparent',
    paddingLeft: 12,
    paddingRight: 12,
    flexDirection: 'column',
    justifyContent: 'center',
  },

  instructions: {
    textAlign: 'center',
    color: '#333333',
    marginBottom: 5,
  },
  realmColor0: {
    backgroundColor: colors.melon,
  },
  realmColor1: {
    backgroundColor: colors.peach,
  },
  realmColor2: {
    backgroundColor: colors.sexysalmon,
  },
  realmColor3: {
    backgroundColor: colors.flamingo,
  },
  realmColor4: {
    backgroundColor: colors.mulberry,
  },
  realmColor5: {
    backgroundColor: colors.grape_jelly,
  },
  realmColor6: {
    backgroundColor: colors.indigo,
  },
  realmColor7: {
    backgroundColor: colors.ultramarine,
  },

  loginView: {
    flex: 1,
    alignItems: 'stretch',
    backgroundColor: colors.charcoal,
    justifyContent: 'center',
    padding: 20,
  },
  loginRow: {
    fontSize: 18,
    padding: 10,
    height: 40,
  },
  loginInput: {
    fontSize: 18,
    padding: 10,
  },
  loginTitle: {
    fontSize: 24,
    height: 45,
    fontWeight: 'bold',
    textAlign: 'center',
    backgroundColor: colors.sexysalmon,
  },
  loginLabel1: {
    backgroundColor: colors.flamingo,
  },
  loginInput1: {
    backgroundColor: colors.mulberry,
    textAlign: 'right',
  },
  loginLabel2: {
    backgroundColor: colors.grape_jelly,
  },
  loginInput2: {
    backgroundColor: colors.indigo,
    textAlign: 'right',
  },
  LoginGap: {
    color: colors.ultramarine,
  },
  loginErrorLabel: {
    height: 80,
    color: 'red',
  },
};

export default StyleSheet.create(styles);
