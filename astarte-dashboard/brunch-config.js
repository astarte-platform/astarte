module.exports = {
    files: {
        javascripts: {
            joinTo: "js/app.js"
        },
        stylesheets: {
            joinTo: "css/app.css"
        }
    },
    paths: {
        watched: ["app/elm", "app/js", "app/assets"]
    },
    plugins: {
        elmBrunch: {
            mainModules: ["app/elm/Main.elm"],
            executablePath: "node_modules/elm/binwrappers",
            outputFolder: "app/js",
            outputFile: "elm-app.js",
            makeParameters: "--debug"
        }
    },
    modules: {
        autoRequire: {
            'js/app.js': ['js/init.js']
        }
    },
    npm: {
        enabled: false,
    },
    overrides: {
        production: {
            plugins: {
                elmBrunch: {
                    makeParameters: []
                }
            }
        }
    }
};
