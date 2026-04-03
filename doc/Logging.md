# Logging Script Notes



### **Additional Supported Escape Codes**

#### **Text Formatting**
| Code   | Description           |
|--------|-----------------------|
| `\033[1m` | Bold/bright          |
| `\033[2m` | Dim                 |
| `\033[3m` | Italic              |
| `\033[4m` | Underline           |
| `\033[5m` | Blink (slow)        |
| `\033[6m` | Blink (rapid)       |
| `\033[7m` | Inverse (swap foreground and background colors) |
| `\033[8m` | Hidden (concealed)  |
| `\033[9m` | Strikethrough       |
| `\033[0m` | Reset (normal text) |

---

#### **Foreground Colors (Standard and Bright)**
| Color          | Standard Code | Bright Code |
|-----------------|---------------|-------------|
| Black          | `\033[30m`    | `\033[90m`  |
| Red            | `\033[31m`    | `\033[91m`  |
| Green          | `\033[32m`    | `\033[92m`  |
| Yellow         | `\033[33m`    | `\033[93m`  |
| Blue           | `\033[34m`    | `\033[94m`  |
| Magenta        | `\033[35m`    | `\033[95m`  |
| Cyan           | `\033[36m`    | `\033[96m`  |
| White          | `\033[37m`    | `\033[97m`  |

---

#### **Background Colors (Standard and Bright)**
| Color          | Standard Code | Bright Code |
|-----------------|---------------|-------------|
| Black          | `\033[40m`    | `\033[100m` |
| Red            | `\033[41m`    | `\033[101m` |
| Green          | `\033[42m`    | `\033[102m` |
| Yellow         | `\033[43m`    | `\033[103m` |
| Blue           | `\033[44m`    | `\033[104m` |
| Magenta        | `\033[45m`    | `\033[105m` |
| Cyan           | `\033[46m`    | `\033[106m` |
| White          | `\033[47m`    | `\033[107m` |

---

#### **Reset Specific Attributes**
| Code     | Description              |
|----------|--------------------------|
| `\033[21m` | Reset bold/bright       |
| `\033[22m` | Reset dim               |
| `\033[23m` | Reset italic            |
| `\033[24m` | Reset underline         |
| `\033[25m` | Reset blink             |
| `\033[27m` | Reset inverse           |
| `\033[28m` | Reset hidden            |
| `\033[29m` | Reset strikethrough     |

