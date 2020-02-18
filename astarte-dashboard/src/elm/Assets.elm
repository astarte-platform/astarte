{-
   This file is part of Astarte.

   Copyright 2018 Ispirata Srl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-}


module Assets exposing
    ( AssetPath(..)
    , dashboardIcon
    , homepageImage
    , loginAstarteMascotte
    , loginBackgroundBottom
    , loginBackgroundTop
    , loginImage
    , loginLogo
    , path
    )


type AssetPath
    = AssetPath String


path : AssetPath -> String
path (AssetPath str) =
    str


loginAstarteMascotte : AssetPath
loginAstarteMascotte =
    AssetPath "/static/img/mascotte-computer.svg"


loginBackgroundTop : AssetPath
loginBackgroundTop =
    AssetPath "/static/img/background-login-top.svg"


loginBackgroundBottom : AssetPath
loginBackgroundBottom =
    AssetPath "/static/img/background-login-bottom.svg"


loginImage : AssetPath
loginImage =
    AssetPath "/static/img/login.svg"


loginLogo : AssetPath
loginLogo =
    AssetPath "/static/img/logo-login.svg"


dashboardIcon : AssetPath
dashboardIcon =
    AssetPath "/static/img/logo.svg"


homepageImage : AssetPath
homepageImage =
    AssetPath "/static/img/homemascotte.svg"
