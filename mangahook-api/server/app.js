const ApiKey = require("./middleware/apiKeyMiddleware")
const express = require("express")
const app = express()
const cors = require("cors")
const bodyParser = require("body-parser")
const mangaRouter = require("./routes/mangaRouter")
const mangaListRouter = require("./routes/mangaListRouter")
const mangaSearch = require("./routes/mangaSearch")

require('dotenv').config()

// Enable CORS for all origins
app.use(cors())
app.use(bodyParser.json())

app.use(ApiKey)
app.use("/api/manga", mangaRouter)
app.use("/api/mangaList", mangaListRouter)
app.use("/api/search", mangaSearch)

app.listen(process.env.PORT, () => {
    console.log(`MangaHook Server running on port ${process.env.PORT} 🎉✨`)
})