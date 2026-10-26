import Foundation

/// Represents a Git worktree
struct Worktree: Identifiable, Hashable {
    let id: UUID
    let path: String
    let branch: String?
    let commitSHA: String
    let isMain: Bool        // Is this the main worktree
    let isPrunable: Bool    // Can be removed (linked worktree that no longer exists)
    let isLocked: Bool      // Is locked to prevent removal
    let lockedReason: String?
    let prunableReason: String?
    let isBare: Bool
    let isDetached: Bool    // HEAD is detached (not on a branch)

    /// Directory name of the worktree
    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    /// Short SHA for display
    var shortSHA: String {
        String(commitSHA.prefix(7))
    }

    init(
        id: UUID = UUID(),
        path: String,
        branch: String? = nil,
        commitSHA: String,
        isMain: Bool = false,
        isPrunable: Bool = false,
        isLocked: Bool = false,
        isDetached: Bool = false,
        lockedReason: String? = nil,
        prunableReason: String? = nil,
        isBare: Bool = false
    ) {
        self.id = id
        self.path = path
        self.branch = branch
        self.commitSHA = commitSHA
        self.isMain = isMain
        self.isPrunable = isPrunable
        self.isLocked = isLocked
        self.isDetached = isDetached
        self.lockedReason = lockedReason
        self.prunableReason = prunableReason
        self.isBare = isBare
    }

    /// Production uses --porcelain -z so tabs, Unicode and newlines in
    /// paths/reasons remain literal. Legacy line-delimited fixtures still work.
    static func parseFromPorcelain(_ output: String) -> [Worktree] {
        let records = output.contains("\0")
            ? output.components(separatedBy: "\0")
            : output.components(separatedBy: .newlines)
        var result: [Worktree] = []
        var path: String?
        var branch: String?
        var sha: String?
        var locked = false
        var prunable = false
        var detached = false
        var bare = false
        var lockReason: String?
        var pruneReason: String?
        func appendRecord() {
            if let path, let commit = sha ?? (bare ? "" : nil) {
                result.append(Worktree(path: path, branch: branch, commitSHA: commit,
                    isMain: result.isEmpty, isPrunable: prunable, isLocked: locked,
                    isDetached: detached, lockedReason: lockReason, prunableReason: pruneReason, isBare: bare))
            }
            path = nil; branch = nil; sha = nil
            locked = false; prunable = false; detached = false; bare = false
            lockReason = nil; pruneReason = nil
        }
        for record in records {
            if record.isEmpty { appendRecord() }
            else if record.hasPrefix("worktree ") { path = String(record.dropFirst(9)) }
            else if record.hasPrefix("HEAD ") { sha = String(record.dropFirst(5)) }
            else if record.hasPrefix("branch ") {
                let ref = String(record.dropFirst(7))
                branch = ref.hasPrefix("refs/heads/") ? String(ref.dropFirst(11)) : ref
            }
            else if record == "detached" { detached = true }
            else if record == "bare" { bare = true }
            else if record == "locked" || record.hasPrefix("locked ") {
                locked = true
                lockReason = record == "locked" ? nil : String(record.dropFirst(7))
            }
            else if record == "prunable" || record.hasPrefix("prunable ") {
                prunable = true
                pruneReason = record == "prunable" ? nil : String(record.dropFirst(9))
            }
        }
        appendRecord()
        return result
    }
}

/// Offline explanations. Opening help never executes a Git command; the
/// optional documentation link is always an explicit user action.
struct GitHelpTopic: Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
    let guidance: String
    let risk: String
    let page: String
    var documentationURL: URL { URL(string: "https://git-scm.com/docs/\(page)")! }

    static func matching(_ query: String) -> [Self] {
        let locale = Locale(identifier: "es")
        let words = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale).split(whereSeparator: \.isWhitespace)
        return all.filter { topic in
            let text = [topic.id, topic.title, topic.summary, topic.guidance, topic.risk].joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            return words.allSatisfy { text.contains($0) }
        }
    }

    static let all: [Self] = [
        .init(id: "basics", title: "Entender Git", summary: "Archivos → preparación → commit → publicación.", guidance: "Editas en tu carpeta. Stage elige qué guardar. Commit crea una versión local. Push la comparte. Git no publica tus cambios solo por guardarlos en el editor.", risk: "Empieza revisando Status y Diff; no cambian tus archivos.", page: "gittutorial"),
        .init(id: "status", title: "Ver qué cambió", summary: "Status distingue preparado, sin preparar, nuevo y en conflicto.", guidance: "Revisa esta lista antes de guardar o sincronizar. Un archivo puede tener cambios preparados y otros todavía sin preparar.", risk: "Solo lectura.", page: "git-status"),
        .init(id: "diff", title: "Comparar archivos y versiones", summary: "Diff muestra las líneas que se añaden y se eliminan.", guidance: "Selecciona un archivo para revisarlo. Distingue el cambio preparado del cambio que todavía queda en tu carpeta.", risk: "Ver un diff no aplica sus cambios.", page: "git-diff"),
        .init(id: "stage", title: "Preparar y quitar de preparación", summary: "Stage selecciona contenido para el próximo commit; unstage lo saca de esa selección.", guidance: "Prepara solo lo que quieres guardar junto. Unstage conserva la edición en el archivo; no es descartar.", risk: "No confundir Unstage con Discard.", page: "git-add"),
        .init(id: "commit", title: "Guardar una versión local", summary: "Commit guarda el contenido preparado con una descripción.", guidance: "Revisa el diff preparado y escribe por qué hiciste el cambio. No incluye automáticamente todo lo editado ni publica en el servidor.", risk: "Amend reemplaza el último commit: coordínalo si ya fue compartido.", page: "git-commit"),
        .init(id: "branch", title: "Trabajar en una rama", summary: "Una rama nombra una línea de trabajo.", guidance: "Crea una para una tarea y cámbiate a ella antes de editar. Una rama no es otra carpeta; usa un worktree si necesitas dos carpetas a la vez.", risk: "Revisa cambios pendientes antes de cambiar de rama.", page: "git-branch"),
        .init(id: "switch", title: "Cambiar de rama", summary: "Switch o checkout actualizan la revisión que tienes abierta.", guidance: "Guarda o aparta cambios cuando Git avise de que podrían sobrescribirse. No fuerces el cambio para ocultar ese aviso.", risk: "Puede cambiar los archivos de tu carpeta.", page: "git-switch"),
        .init(id: "clone", title: "Clonar un proyecto", summary: "Clone crea una copia local de un repositorio.", guidance: "Verifica la URL y elige una carpeta de destino. Abrir un repositorio que ya tienes no requiere volver a clonarlo.", risk: "Descarga datos y crea archivos; revisa la confianza del proyecto.", page: "git-clone"),
        .init(id: "init", title: "Empezar un repositorio", summary: "Init añade seguimiento Git a una carpeta.", guidance: "Después revisa qué archivos deben ignorarse antes del primer commit. No subas contraseñas ni archivos privados.", risk: "Crear el repositorio no publica nada.", page: "git-init"),
        .init(id: "fetch", title: "Consultar cambios del servidor", summary: "Fetch descarga objetos y actualiza referencias remotas.", guidance: "Úsalo para saber qué hay disponible antes de integrar. Tu rama actual no se fusiona por hacer fetch.", risk: "Usa red y actualiza referencias locales.", page: "git-fetch"),
        .init(id: "pull", title: "Traer e integrar cambios", summary: "Pull descarga y después integra según la estrategia elegida.", guidance: "Revisa si usarás merge o rebase y si tienes cambios pendientes. Si hay conflictos, resuélvelos antes de continuar.", risk: "Puede cambiar archivos e historial local.", page: "git-pull"),
        .init(id: "push", title: "Publicar commits", summary: "Push actualiza referencias del repositorio remoto.", guidance: "Comprueba rama y destino. Si el servidor rechaza el envío, consulta sus cambios antes de decidir cómo integrarlos.", risk: "Afecta a otras personas. Force push puede reemplazar su historial.", page: "git-push"),
        .init(id: "remote", title: "Elegir el servidor", summary: "Un remoto, como origin, es un nombre asociado a una URL.", guidance: "Fetch y push pueden tener destinos distintos. Verifica la URL y los permisos antes de publicar.", risk: "Cambiar la URL cambia el destino de futuras operaciones.", page: "git-remote"),
        .init(id: "merge", title: "Unir líneas de trabajo", summary: "Merge integra otra rama en la actual.", guidance: "Primero sitúate en la rama que recibirá el trabajo. Resuelve conflictos, prepara las resoluciones y completa la operación.", risk: "Puede modificar archivos y crear un commit de unión.", page: "git-merge"),
        .init(id: "rebase", title: "Reaplicar commits sobre otra base", summary: "Rebase reconstruye una secuencia de commits sobre otra revisión.", guidance: "Es útil para reorganizar trabajo local. Resuelve cada conflicto y continúa, o aborta si no quieres completar la operación.", risk: "Cambia identidades de commits. No reescribas trabajo compartido sin coordinarlo.", page: "git-rebase"),
        .init(id: "stash", title: "Apartar cambios temporalmente", summary: "Stash conserva cambios para retomarlos después.", guidance: "Apply los recupera sin quitar la entrada. Pop intenta recuperarlos y retirar la entrada; si hay conflictos, no presupongas que desapareció. Ver sus archivos es solo inspección.", risk: "Drop elimina la entrada. Los archivos nuevos requieren incluir untracked al guardar.", page: "git-stash"),
        .init(id: "worktrees", title: "Dos tareas en dos carpetas", summary: "Un worktree es otra carpeta de trabajo del mismo repositorio.", guidance: "Elige una tarea, una rama y una carpeta nueva. Cada carpeta tiene sus archivos, HEAD y preparación; comparten objetos y ramas. Para trabajar a la vez en otra tarea, crea otra rama. Usa Open para entrar y Finder para localizarla.", risk: "Eliminar un worktree elimina su carpeta. No es lo mismo que cerrar su pestaña.", page: "git-worktree"),
        .init(id: "detached", title: "Inspeccionar una revisión sin rama", summary: "Detached HEAD significa que estás situado en un commit, no en una rama.", guidance: "Sirve para revisar una versión concreta. Si vas a conservar nuevos commits, crea una rama que los nombre antes de abandonar esa revisión.", risk: "Sin una referencia, esos commits pueden dejar de ser accesibles.", page: "gitglossary"),
        .init(id: "graph", title: "Leer el grafo y su minimapa", summary: "Cada nodo es un commit y sus conexiones muestran parentesco.", guidance: "El minimapa resume la historia local de la revisión actual. Arrastra y suelta para saltar por SHA. El salto limpia la búsqueda y el filtro de autor. Las historias densas se simplifican visualmente, conservando el índice completo.", risk: "No descarga historia faltante de clones superficiales ni incluye automáticamente ramas ajenas a la consulta actual.", page: "git-log"),
        .init(id: "revert", title: "Deshacer mediante otro commit", summary: "Revert registra un cambio inverso sin borrar el commit original.", guidance: "Suele ser apropiado para corregir trabajo compartido. Revisa el resultado y resuelve conflictos si aparecen.", risk: "Modifica archivos y añade historial.", page: "git-revert"),
        .init(id: "reset", title: "Mover una rama o cambiar preparación", summary: "Reset tiene efectos distintos según sus opciones.", guidance: "Soft conserva preparación y archivos; mixed cambia preparación; hard también reemplaza archivos rastreados. Elige por el efecto, no por el nombre.", risk: "Hard puede destruir cambios sin commit. Reflog no recupera cualquier edición sin guardar.", page: "git-reset"),
        .init(id: "discard", title: "Descartar una edición", summary: "Restore o discard reemplazan contenido en archivos.", guidance: "Inspecciona el diff y confirma la ruta exacta. Quitar de preparación es otra operación y conserva la edición.", risk: "Las ediciones descartadas sin commit pueden ser irrecuperables.", page: "git-restore"),
        .init(id: "cherry-pick", title: "Traer un commit concreto", summary: "Cherry-pick reaplica el cambio de un commit en tu rama actual.", guidance: "Úsalo para elegir un arreglo sin integrar toda la rama. Revisa posibles dependencias de otros commits.", risk: "Crea nuevos commits y puede producir conflictos.", page: "git-cherry-pick"),
        .init(id: "reflog", title: "Encontrar una posición anterior", summary: "Reflog registra movimientos locales de referencias.", guidance: "Localiza la revisión deseada y crea una rama de rescate antes de decidir cómo recuperarla.", risk: "No es una copia de seguridad permanente ni un historial de todas las ediciones de archivos.", page: "git-reflog"),
        .init(id: "tag", title: "Marcar una versión", summary: "Una etiqueta nombra una revisión, por ejemplo una entrega.", guidance: "Distingue etiquetas ligeras de anotadas o firmadas. Revisa qué etiquetas publicarás.", risk: "Mover una etiqueta publicada puede confundir a otras personas.", page: "git-tag"),
        .init(id: "bisect", title: "Encontrar cuándo apareció un fallo", summary: "Bisect reduce el intervalo entre una revisión buena y una mala.", guidance: "Prueba cada revisión propuesta y marca el resultado. Finaliza con reset de bisect para volver a tu posición inicial.", risk: "Cambia temporalmente la revisión de la carpeta; conserva primero tu trabajo.", page: "git-bisect"),
        .init(id: "blame", title: "Investigar una línea", summary: "Blame relaciona líneas con commits del historial.", guidance: "Abre el commit y su contexto para entender la decisión; el último autor de una línea no explica necesariamente su origen completo.", risk: "Solo lectura.", page: "git-blame"),
        .init(id: "submodule", title: "Usar un repositorio dentro de otro", summary: "Un submódulo conserva una referencia a una revisión de otro repositorio.", guidance: "Revisa tanto el estado del submódulo como el cambio de referencia en el proyecto padre.", risk: "Actualizarlo puede cambiar archivos y descargar datos de otra URL.", page: "git-submodule"),
        .init(id: "ignore", title: "Evitar archivos que no deben versionarse", summary: ".gitignore define patrones para archivos no rastreados.", guidance: "Ignora resultados de compilación y configuración privada antes de añadirlos. Ignorar un archivo ya rastreado no lo elimina del historial.", risk: "Una contraseña ya publicada requiere rotación; ocultarla ahora no revoca su acceso.", page: "gitignore"),
        .init(id: "config", title: "Configurar identidad y comportamiento", summary: "Git puede tener configuración de sistema, usuario y repositorio.", guidance: "Comprueba el alcance antes de cambiar nombre, correo o estrategias. Los Ajustes de GitMac y las opciones visuales del grafo son controles distintos.", risk: "Un ajuste global afecta a otros repositorios.", page: "git-config"),
        .init(id: "terminal", title: "Funciones avanzadas y manual completo", summary: "La guía integrada explica los flujos principales; el manual enlazado contiene el catálogo de comandos de Git.", guidance: "Consulta git help y git help <comando> para tu versión instalada. Leer esta ayuda no ejecuta comandos. Verifica carpeta, rama y consecuencias antes de usar la terminal.", risk: "Los comandos de borrado o reescritura no son equivalentes a cerrar una vista.", page: "git")
    ]
}
