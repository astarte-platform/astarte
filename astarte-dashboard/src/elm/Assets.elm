module Assets
    exposing
        ( AssetPath(..)
        , path
        , loginImage
        , dashboardIcon
        , homepageImage
        )


type AssetPath
    = AssetPath String


path : AssetPath -> String
path (AssetPath str) =
    str


loginImage : AssetPath
loginImage =
    AssetPath "/static/img/login.svg"


dashboardIcon : AssetPath
dashboardIcon =
    AssetPath "/static/img/logo.svg"


homepageImage : AssetPath
homepageImage =
    AssetPath "/static/img/homemascotte.svg"
